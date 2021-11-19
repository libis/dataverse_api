# frozen_string_literal: true

require_relative 'base'

module Dataverse
  class Dataset < Base

    attr_reader :id

    def self.id(id)
      Dataset.new(id)
    end

    def self.pid(pid)
      data = api_call('datasets/:persistentId', params: {'persistentId' => pid})
      Dataset.new(data['id'])
    end

    def self.create(data:, dataverse:)
      new_dataset(dataverse, data)
    end

    def self.import(data:, dataverse:, pid:, publish: false, ddi: false)
      new_dataset(dataverse, data, import: pid, publish: publish, ddi: ddi)
    end

    def delete
      raise Error.new 'Can only delete draft version' unless draft_version
      versions
      result = call('versions/:draft', method: :delete)
      @version_data.delete(:draft)
      @metadata.delete(:draft)
      @files.delete(:draft)
      @version_numbers&.delete(:draft)
      init({}) if published_versions.empty?
      result['message']
    end

    def submit
      call('submitForReview', method: post)
    end

    def reject(reason)
      call('returnToAuthor', method: post, body: reason)
    end

    def publish(major: true)
      result = call('actions/:publish', method: :post, 
        params: {type: major ? 'major' : 'minor'}, format: :status
      )
      return "Dataset #{pid} published" if result == 200
      return "Dataset #{pid} waiting for review" if result == 202
    end

    def call(url, **args)
      api_call("datasets/#{id}/#{url}", **args)
    end

    def pid(version: :latest)
      version_data(version).fetch('datasetPersistentId')
    end

    def size
      data = call("storagesize", params: {includeCached: 'true'})
      data['message'][/[,\d]+/].delete(',').to_i
    end

    def versions
      @version_numbers ||= begin
        data = [:latest, :published] + [draft_version].compact + published_versions
        data.delete(:published) unless published_versions.size > 0
        data
      end
    end

    def draft_version
      return :draft if @version_data.keys.include?(:draft)
    end

    def published_versions
      @published_versions ||= call('versions').map do |x|
        next unless x['versionState'] == 'RELEASED'
        "#{x['versionNumber']}.#{x['versionMinorNumber']}".to_f
      end.compact
    end

    def version(version = :latest)
      resolve_version(version, raise_if_not_found: false)
    end

    def title(version: :latest)
      metadata(version: version).fetch('title')
    end

    def author(version: :latest)
      metadata(version: version).fetch('author').first.fetch('authorName')
    end

    def updated(version: :latest)
      Time.parse(version_data(version).fetch('lastUpdateTime')).getlocal
    end

    def created(version: :latest)
      Time.parse(version_data(version).fetch('createTime')).getlocal
    end

    def published(version: :published)
      return nil unless version_data(version).has_key?('releaseTime')
      Time.parse(version_data(version).fetch('releaseTime')).getlocal
    end

    def metadata_fields(version: :latest)
      metadata(version: version)&.keys || []
    end

    MD_TYPES_XML=['ddi', 'oai_ddi', 'dcterms', 'oai_dc', 'Datacite', 'oai_datacite']
    MD_TYPES_JSON=['schema.org', 'OAI_ORE', 'dataverse_json']
    MD_TYPES=['rdm', 'raw'] + MD_TYPES_JSON + MD_TYPES_XML

    def export_metadata(md_type)
      return nil unless version(:published)
      format = case md_type.to_s
      when *MD_TYPES_XML
        :xml
      when *MD_TYPES_JSON
        :json
      when 'rdm'
        return rdm_data
      when 'raw'
        return raw_data
      else
        raise Error.new("Unknown metadata format: '#{md_type}'")
      end
      api_call('datasets/export', params: {exporter: md_type, persistentId: pid}, format: format)
    end

    def rdm_data(version: :published)
      return nil unless version(version)
      api_data
        .merge(version_data(version))
        .merge('metadata' => metadata(version: version))
        .merge('files' => files(version: version))
        .tap do |h|
          h['license'] = {
            'label' => license_name(h),
            'uri' => license_url(h),
            'iconUrl' => license_icon(h)
          }
        end
    end

    def raw_data(version: :latest, with_files: false)
      result = api_data.dup.merge(version_data(resolve_version(version)))
      result['metadataBlocks'] = call("/versions/#{version_string(version)}/metadata")
      result['files'] = call("/versions/#{version_string(version)}/files") if with_files
      { 'datasetVersion' => result }
    end

    def metadata(version: :latest)
      @metadata[resolve_version(version)] || {}
    end

    def files(version: :latest)
      @files[resolve_version(version)] || []
    end

    def download_size(version: :latest)
      data = call("versions/#{version_string(version)}/downloadsize")
      data['message'][/[,\d]+/].delete(',').to_i
    end

    def download(filename = 'dataverse_files.zip', version: nil)
      if version
        v = version_string(version)
        raise Error.new("Version '#{version}' does not exist") unless v
        version = v
      end
      File.open(filename, 'w') do |f|
        size = 0
        block = proc do |response|
          response.value
          response.read_body do |chunk|
            size += chunk.size
            f.write chunk
          end
        rescue Net::HTTPServerException
          return false
        end
        url = 'access/dataset/:persistentId'
        url += "/versions/#{version}" if version
        params = {persistentId: pid}
        api_call(url, params: params, block: block)
        f.close
        size
      end
    end

    protected

    def initialize(id)
      @id = id
      init(get_data)
    end

    def init(data)
      @version_data = {}
      @metadata = {}
      @files = {}
      @version_numbers = nil
      @published_versions = nil
      super(process_data(data))
    end

    def get_data
      api_call("datasets/#{id}")
    end

    def resolve_version(version, raise_if_not_found: true)
      _version = version

      version = case version
      when ':draft', 'draft'
        :draft
      when ':latest', 'latest'
        :latest
      when ':published', 'published', ':latest-published', 'latest-published'
        :published
      when Numeric, String
        version.to_f
      else
        version
      end

      case version
      when :latest
        version = draft_version || published_versions.max
      when :published
        version = published_versions.max
      end

      unless @version_data.keys.include?(version)
        version = versions.find {|x| x == version}
        raise VersionError.new(_version) if version.nil? && raise_if_not_found
        return nil unless version
        data = call("versions/#{version}")
        process_version_data(data)
      end

      version
    end

    def version_string(version)
      v = resolve_version(version)
      case v
      when Symbol
        ":#{v}"
      when Numeric
        v.to_s
      else
        v
      end
    end

    def version_data(version)
      @version_data[resolve_version(version)].transform_keys { |k| k == 'id' ? 'versionId' : k }
    end

    private

    def license_url(h)
      h.fetch('termsOfUse')[/(?<=href=")[^"]*(?=")/] rescue nil
    end

    def license_name(h)
      h.fetch('termsOfUse')[/[^>]*(?=<\/a>.$)/] rescue nil
    end

    def license_icon(h)
      h.fetch('termsOfUse')[/(?<=src=")[^"]*(?=")/] rescue nil
    end

    def process_data(data)
      return {} if data.nil? || data.empty?
      version_data = data.delete('latestVersion')
      process_version_data(version_data)
      data
    end

    def process_version_data(data)
      metadata = pack_metadata(data.delete('metadataBlocks'))
      files = pack_files(data.delete('files'))
      version = get_version_number(data)
      store_data(version, data, metadata, files)
      version
    end

    def get_version_number(data)
      case data['versionState']
      when 'DRAFT'
        :draft
      when 'RELEASED'
        "#{data['versionNumber']}.#{data['versionMinorNumber']}".to_f
      else
        raise Error.new("Unsupported version state: '#{data['versionState']}")
      end
    end

    def store_data(version, data, metadata, files)
      @version_data[version] = data.freeze
      @metadata[version] = metadata.freeze
      @files[version] = files.freeze
    end

    def pack_metadata(metadata)
      data = {}
      metadata.each_value do |block|
        block['fields'].each do |field|
          data[field['typeName']] = field_to_value(field)
        end
      end
      data
    end

    def pack_files(files)
      files.map do |file|
        detail = file.delete('dataFile')
        file.merge(detail)
      end
    end

    def field_to_value(field)
      case field['typeClass']
      when 'primitive'
        return field['value']
      when 'controlledVocabulary'
        return field['value']
      when 'compound'
        compound_to_value(field['value'])
      else
        raise Error.new("Unsupported typeClass: '#{field['typeClass']}'")
      end
    end

    def compound_to_value(data)
      return data.map {|x| compound_to_value(x)} if data.is_a?(Array)
      hash = {}
      data.values.each do |v|
        hash[v['typeName']] = field_to_value(v)
      end
      hash
    end

    def self.parse(dataverse, data, import: nil, publish: false, ddi: false)

      dataverse = dataverse.id if dataverse.is_a?(Dataverse)

      data = StringIO.new(data.to_json) if data.is_a?(Hash)

      if data.is_a?(String)
        begin
          if File.exist?(data)
            data = File.open(data, 'r')
          elsif ddi || JSON::parse(data)
            data = StringIO.new(data)
          end
        rescue JSON::ParserError, File
          data = nil
        end
      end
      
      unless data.is_a?(File) || data.is_a?(StringIO)
        raise Error.new("Data could not be parsed. Should be a Hash, filename or JSON string.")
      end

      url = "dataverses/#{dataverse}/datasets"
      url += '/:import' if import

      params = {release: publish ? 'yes' : 'no'}
      params[:pid] = import if import

      headers = {content_type: :json}
      headers[:content_type] = :xml if ddi

      result = api_call(url, method: :post, headers: headers, body: data, params: params)
      puts result

      return Dataset.id(result['id'])

    ensure
      data.close if data.is_a?(File)

    end

  end
end
