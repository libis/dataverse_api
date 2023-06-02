# frozen_string_literal: true

require_relative 'base'
require_relative 'dataset'

module Dataverse
  class Dataverse < Base

    attr_reader :id

    def self.id(id)
      new(id)
    rescue RestClient::NotFound
      nil
    end

    def self.root
      id(':root')
    end

    SAMPLE_DATA= {
      name: 'new dataverse',
      alias: 'new_dv',
      dataverseContacts: [
        { contactEmail: 'abc@def.org'}
      ],
      affiliation: 'My organization',
      description: 'My new dataverse',
      dataverseType: 'ORGANIZATIONS_INSTITUTIONS'
    }

    TYPES = %w'DEPARTMENT JOURNALS LABORATORY ORGANIZATIONS_INSTITUTIONS RESEARCHERS RESEARCH_GROUP RESEARCH_PROJECTS TEACHING_COURSES UNCATEGORIZED'

    def create(data)
      data = StringIO.new(data.to_json) if data.is_a?(Hash)
      if data.is_a?(String)
        begin
          if File.exist?(data)
            data = File.open(data, 'r')
          elsif JSON::parse(data)
            data = StringIO.new(data)
          end
        rescue JSON::ParserError, File
          data = nil
        end
      end
      
      unless data.is_a?(File) || data.is_a?(StringIO)
        raise Error.new("Data could not be parsed. Should be a Hash, filename or JSON string.")
      end

      result = call('', method: :post, body: data)
      
      dv = Dataverse.new(nil)
      dv.init(result)
      dv.instance_variable_set('@id', result['id'])
      return dv

    ensure
      data.close if data.is_a?(File)

    end

    def publish
      call("actions/:publish", method: :post)
      return "Dataverse #{id} published"
    end

    def delete
      call('', method: :delete)['message']
    end

    def call(url, **args)
      api_call("dataverses/#{id}/#{url}", **args)
    end

    def each_child(&block)
      data = call("contents")
      data.each do |x|
        begin
          case x['type']
          when 'dataverse'
            dv = Dataverse.id(x['id'])
            data << (block_given? ? yield(child) : child)

          when 'dataset'
            ds = Dataset.id(x['id'])
            result << ds if ds.version
          else
            raise Error.new("Unsupported type: #{x['type']} (#{x['name']})")
          end
        rescue => e
          puts "ERROR: Skipped creating #{x['type']} object '#{x['id']}' : '#{e.message}'."
        end
      end
      result
    end


    def children(&block)
      if @children && @children.is_a?(Array)
        @children.each { |child| yield(child) } if block_given?
      else
        @children = begin
          result = []
          data = call("contents")
          data.each do |x|
            begin
              case x['type']
              when 'dataverse'
                dv = Dataverse.id(x['id'])
                yield dv if block_given?
                result << dv
              when 'dataset'
                ds = Dataset.id(x['id'])
                if ds.version
                  yield ds if block_given?
                  result << ds
                end
              else
                raise Error.new("Unsupported type: #{x['type']} (#{x['name']})")
              end
            rescue => e
              puts "ERROR: Skipped #{x['type']} object '#{x['id']}' : '#{e.message}'."
            end
          end
          result
        end
      end
      @children
    end

    def each_dataverse(&block)
      data = []
      children do |child|
        if child.is_a?(Dataverse)
          data << (block_given? ? yield(child) : child)
          data += child.each_dataverse(&block)
        end
      end
      data
    end

    def each_dataset(&block)
      data = []
      children do |child|
        if child.is_a?(Dataverse)
          data += child.each_dataset(&block)
        elsif child.is_a?(Dataset)
          data << (block_given? ? yield(child) : child)
        end
      end
      data
    end

    def size
      @size ||= begin
        data = api_call("dataverses/#{id}/storagesize")
        data['message'][/[,\d]+/].delete(',').to_i
      end
    end

    def rdm_data
      api_data
    end

    def export_metadata(md_type)
      case md_type.to_s
      when 'rdm'
        return rdm_data
      else
        raise Error.new("Unknown metadata format: '#{md_type}'")
      end
    end

    protected

    def initialize(id)
      @id = id
      init(get_data)
    end

    def init(data)
      @size = nil
      @children = nil
      super(data)
    end

    def get_data
      return unless id
      api_call("dataverses/#{id}")
    end

  end
end