# Dataverse API gem

This gem wraps the Dataverse API in a set of Ruby classes. You can use the classes to perform the API calls and process the result on the Ruby objects. It builds upon the rest-client gem to perform the low-level REST API calls. For more information about Dataverse and the API, see https://dataverse.org/ and https://guides.dataverse.org/en/latest/api/index.html

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dataverse'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install dataverse

## Usage

In order to configure the API calls, you need to define at least two environment variables:

 - API_URL: the full url of the Dataverse repository you want to access. This URL should be give up to and including the '/api' path. Optionally, a version portion can be added to the path.
 - API_TOKEN: a token to identify and authorize the user. Note that for some API calls a superuser token may be required.
 - RESTCLIENT_LOG: if defined, will log the REST API calls to the given file. Set to 'stdout' if you want to log to screen.

You can set these environment variables in a .env file if you wish as the dotenv gem is used here. The file .env.template is provided as a starting point.

## Dataverse::Dataverse

The class that captures the api dealing with Dataverse collections.

### Accessing an existing Dataverse collection

You can create a new instance by supplying the id or alias of an existing Dataverse collection to the constructor:

```ruby
Dataverse::Dataverse.id('my_dataverse')
# => #<Dataverse::Dataverse:0x0...>
```

You can pass the value ':root' or use the #root class method if you want to access the Dataverse root collection.

```ruby
Dataverse::Dataverse.id(':root') == Dataverse::Dataverse.root
# => true
```

### Creating a new Dataverse collection

To create a new Dataverse collection, you should first open an instance for the parent Dataverse collection, then call the #create method on it, supplying either a Hash, a file name or a JSON string.

```ruby
parent_dv = Dataverse::Dataverse.id('parent_dv')
# => #<Dataverse::Dataverse:0x0...>

new_dv = parent_dv.create(name: 'My new dataverse', alias: 'new_dv', ...)
# => #<Dataverse::Dataverse:0x0...>
```

A sample data hash for a new dataset is provided in
```ruby
Dataverse::Dataverse::SAMPLE_DATA
# => {:name=>"new dataverse", :alias=>"new_dv", :dataverseContacts=>[
#    {:contactEmail=>"abc@def.org"}], :affiliation=>"My organization",
#     :description=>"My new dataverse", :dataverseType=>"ORGANIZATIONS_INSTITUTIONS"}
```
and the list of valid values for the field 'dataverseType' can be found at:
```ruby
Dataverse::Dataverse::TYPES
# => ["DEPARTMENT", "JOURNALS", "LABORATORY", "ORGANIZATIONS_INSTITUTIONS", 
#     "RESEARCHERS", "RESEARCH_GROUP", "RESEARCH_PROJECTS", "TEACHING_COURSES", 
#     "UNCATEGORIZED"]
```

All the metadata of an existing Dataverse collection can be retrieved as a Hash with the #rdm_data method:

```ruby
parent_dv.rdm_data
# => {"id"=>5, "alias"=>"parent_dv", ...}
```

The resulting Hash can be saved to a file and used to create a new Dataverse collection:

```ruby
data = parent_dv.rdm_data.dup
data['alias'] = 'new_dv'
filename = 'dataverse.json'
File.open(filename, 'wt') { |f| f.write JSON.pretty_generate(data) }
new_dv = parent_dv.create(filename)
# => #<Dataverse::Dataverse:0x0...>
```

### Deleting a Dataverse collection

```ruby
new_dv.delete
# => {"message" => "Dataverse 15 deleted"}
```

### Publishing a Dataverse collection

```ruby
new_dv.publish
# => "Dataverse 15 published"

new_dv.publish
# => Dataverse::Error: Dataverse new_dv has already been published
```

Note that if a Dataverse collection was already published, the call will raise a Dataverse::Error exception.

### Access properties of a Dataverse collection

The properties of a Dataverse collection can be accessed similar to a Hash:

```ruby
parent_dv.keys
# => ["id", "alias", "name", "affiliation", "dataverseContacts", "permissionRoot",
#     "description", "dataverseType", "ownerId", "creationDate"]

parent_dv['alias']
# => "parent_dv"

parent_dv.fetch('alias')
# => "parent_dv"
```

Only the above Hash methods are implemented on the Dataverse class. For other Hash operations, you can access the data Hash directly:

```ruby
parent_dv.api_data.select {|k,v| k =~ /^a/ }
# => {"alias" = "parent_dv", "affiliation" => "My organization"}

parent_dv.api_data.values
# => [5, "parent_dv", ...]
```

Note that the data Hash is frozen and using methods on the data Hash that change the contents of the Hash (e.g. #reject! and #delete) will throw a FrozenError exception. If you want to manipulate the Hash, you should create a copy of the Hash:

```ruby
parent_dv.api_data['id'] = 123456
# => FrozenError: can't modify a frozen Hash: ...

data = parent_dv.api_data.dup
# => {"id" => 5, "alias" => "parent_dv", ...}

data.delete('id')
# => 123456

data['alias'] = 'new_dv'
# => "new_dv"

data
# => {"alias" => "new_dv", ...}
```

The id or alias that was used to instantiate the Dataverse collection:

```ruby
parent_dv.id
# => "parent_dv"

new_dv.id
# => 15
```

To get the id or alias explicitly, use the Hash methods:

```ruby
parent_dv['id']
# => 5

parent_dv['alias']
# => "parent_dv"
```

### Report the data file size of a Dataverse collection (in bytes)

```ruby
parent_dv.size
# => 123456789
```

### Browsing

Get an array of child Dataverse collections and datasets:

```ruby
parent_dv.children
# => [#<Dataverse::Dataverse:0x0...>, #<Dataverse::Dataset:0x0...>]
```

Iterate over all child Dataverse collections recursively:

```ruby
parent_dv.each_dataverse do |dv|
    puts dv.id
end
# => 10
# => 15
# ...
```

Iterate over all child datasets recursively:

```ruby
parent_dv.each_dataverse do |dv|
    puts dv.size
end
# => 123456
# => 456123
# ...
```

## Dataverse::Dataset

The class that encapsulates the dataset related API.

### Accessing an existing dataset

A new Dataset instance can be obtained from the parent Dataverse collection's #children call or can be directly instantiated if you know the dataset's id or persistent identifier:

```ruby
ds = parent_dv.children[1]
# => #<Dataverse::Dataset:0x0...>

Dataverse::Dataset.new(25)
# => #<Dataverse::Dataset:0x0...>

Dataverse::Dataset.pid('doi:10.5072/FK2/J8SJZB')
# => #<Dataverse::Dataset:0x0...>
```

### Creating a new dataset

A new dataset can only be created on an existing Dataverse collection. You should supply either a Hash, a file name or a JSON string to the #create_dataset method.

```ruby
ds = parent_dv.create_dataset(
    'datasetVersion' => {
        'metadataBlocks' => {
            'citation' => {
                ...
            }
        }
)
# => #<Dataverse::Dataset: 0x0...>
```

All the metadata of an existing dataset required to create a new dataset can be retrieved as a Hash with the #raw_data method:

```ruby
data = ds.raw_data
# => {"datasetVersion" => {"metadataBlocks" => {"citation" => {...}}}}
```

The resulting Hash can be used to create a new dataset, either directly or by saving it to a file.

```ruby
data = ds.raw_data
new_ds = parent_dv.create_dataset(data)
# => #<Dataverse::Dataset:0x0...>

filename = 'dataset.json'
File.open(filename, 'wt') { |f| f.write JSON.pretty_generate(data) }
new_ds = parent_dv.create_dataset(filename)
# => #<Dataverse::Dataset:0x0...>
```

### Importing a dataset

The #import_dataset method on a Dataverse collection allows to import an existing dataset. The dataset should be registred and its persisten identifier should be supplied in the pid argument. The data argument is similar to the #create_dataset method.

```ruby
data = 'dataset.json'
pid = 'doi:ZZ7/MOSEISLEYDB94'
ds = parent_dv.import_dataset(data, pid: pid)
# => #<Dataverse::Dataset:0x0...>
```

Optionally, upon importing, you can immediately publish the imported dataset.

```ruby
data = 'dataset.json'
pid = 'doi:ZZ7/MOSEISLEYDB94'
ds = parent_dv.import_dataset(data, pid: pid, publish: true)
ds.versions
# => [:latest, :published, 1.0]
```

If you have DDI data instead of Dataverse JSON, you can import as well:

```ruby
data = 'dataset_ddi.xml'
pid = 'doi:ZZ7/MOSEISLEYDB94'
ds = parent_dv.import_dataset(data, pid: pid, ddi: true)
# => #<Dataverse::Dataset:0x0...>
```

### Deleting a dataset

```ruby
ds.delete
# => 'Draft version of dataset 53 deleted'
```

Only the draft version of a dataset can be deleted. If there is only a draft version in the repository, the entire dataset will be deleted. Note that the Ruby Dataverse::Dataset object will still exist and it will still hold the cached data for any version other than the draft version.

### Access dataset properties

The Dataset properties can be accessed just like with the Dataverse class:

```ruby
ds.keys
# => ["id", "identifier", "persistentUrl", "protocol", "authority", "publisher",
#     "publicationDate", "storageIdentifier", "latestVersion"]

ds['identifier']
# => "FK2/J8SJZB"

ds.fetch('identifier')
# => "FK2/J8SJZB"

ds.api_data.keys
# => ["id", "identifier", "persistentUrl", "protocol", "authority", "publisher",
#     "publicationDate", "storageIdentifier", "latestVersion"]

ds.api_data['identifier']
# => "FK2/J8SJZB"
```

The id or pid of the Dataset:

```ruby
ds.id
# => "25"

ds.pid
# => "doi:10.5072/FK2/J8SJZB"
```

The title and author in the metadata of the latest version:

```ruby
ds.title
# => "My new dataset"

ds.author
# => "Lastname, Firstname"
```

Some timestamps:

```ruby
ds.created
# => 2021-02-11 18:05:46 +0100

ds.updated
# => 2021-02-11 18:34:47 +0100

ds.published
# => 2021-02-11 18:34:47 +0100
```

### Accessing metadata

```ruby
ds.metadata_fields
# => ["title", "alternativeTitle", "alternativeURL", "otherId", "author", ...]

ds.metadata
# => { "title" => "My new dataset",
#      "author" => [
#        {
#          "authorName" => "Lastname, Firstname",
#          "authorIdentifierScheme" => "ORCID",
#          "authorIdentifier" => "0000-0001-2345-6789"
#        }
#      ],
#      ...
#    }
```

### Exporting metadata

```ruby
md_type = 'dataverse_json'
ds.export_metadata(md_type)
# => { ... }

md_type = 'raw'
ds.export_metadata(md_type) == ds.raw_data
# => true

Dataverse::Dataset::MD_TYPES
# => ["rdm", "raw", "schema.org", "OAI_ORE", "dataverse_json", 
#     "ddi", "oai_ddi", "dcterms", "oai_dc", "Datacite", "oai_datacite"]

# Note: format types 'ddi' and after that are XML formats; anything else is JSON.

Dataverse::Dataset::MD_TYPES_XML
# => ["ddi", "oai_ddi", "dcterms", "oai_dc", "Datacite", "oai_datacite"]

Dataverse::Dataset::MD_TYPES_JSON
# => ["schema.org", "OAI_ORE", "dataverse_json"]

# Note: JSON metadata will be converted into a Hash and returned as a Hash, 
#       to improve parsing and manipulation of the metadata:
data = ds.export_metadata('schema.org')
# => {"@context"=>"http://schema.org", "@type"=>"Dataset", ...}
```

The resulting Hash can be used to create a new dataset, either directly or by saving it to a file.

```ruby
data = ds.raw_data
new_ds = parent_dv.create_dataset(data)
# => #<Dataverse::Dataset:0x0...>

filename = 'dataset.json'
File.open(filename, 'wt') { |f| f.write JSON.pretty_generate(data) }
new_ds = parent_dv.create_dataset(filename)
# => #<Dataverse::Dataset:0x0...>
```

If the metadata type is a XML format, the data will be a REXML::Document instance:

```ruby
data = ds.export_metadata('dcterms')
# => <UNDEFINED> ...</>

data.write(indent: 2)
# <?xml version='1.0' encoding='UTF-8'?>
#   <metadata xmlns:dcterms='http://purl.org/dc/elements/1.1/' ...>
#   <dcterms:title>My new dataset</dcterms:title>
#   ...
# </metadata>

File.open('dataset_dcterms.xml') 'wt') do |f|
  f.write data
end
```

The 'rdm' metadata format is not one of the officially supported metadata output formats, but a slightly more compact version of the 'dataverse_json' format. It can be accessed directly using the #rdm_data method:

```ruby
ds.rdm_data
# => {"id"=>5, "versionId"=>8, ...,
#     "metadata"=> {"title"=>"My new dataset", ....}}

md_type = 'rdm'
ds.export_metadata(md_type) == ds.rdm_data
# => true
```

The 'raw' metadata format is the format that is required for the creation and import of datasets.

```ruby
data = ds.export_metadata('raw')
#=> {"datasetVersion"=>{"id"=>25, ...}}

data == ds.raw_data
# => true

data.dig('datasetVersion', 'files')
# => nil

ds.raw_data(with_files: true).dig('datasetVersion', 'files')
# => [{"description"=>"data file", "label"=>"file.pdf", ...}]
```

### Report the data file size of a Dataset (in bytes)

```ruby
ds.size
# => 123456789
```

### Accessing dataset files
```ruby
ds.files
# => [ { "description"=>"File descripion",
#        "label"=>"file.pdf", 
#        "id"=>16,
#        "persistentId"=>"doi:10.5072/FK2/J8SJZB/2QPLAC",
#        ...
#      }
#    ]
```

To download datafiles, you can:

1. Download all files:

```ruby
ds.download
# => downloads all files as 'dataset_files.zip' for the latest version

ds.download 'files.zip'
# => use 'files.zip' as target file

ds.download version: '1.0'
# => downloads all files for the version '1.0'
```

2. Download a specific file

```ruby
# TODO
```

### Accessing dataset versions

```ruby
ds.versions
# => [:latest, :published, :draft, 3.0, 2.0, 1.0]

ds.published_versions
# => [1.0, 2.0, 3.0]

ds.draft_version
# => :draft
# will return nil if there is no draft version

ds.version(:published)
# => 3.0

ds.version(:latest)
# => :draft

ds.version(2)
# => 2.0

ds.version(4)
# => nil
```

Use the #versions to get a list of valid versions and the #version method resolves the given version name to the version number or the special version :draft. Valid version names are:

- :draft, ':draft' or 'draft' => the draft version, if it exists
- :latest, ':latest', or 'latest' => the latest version: draft if it exists, the last published version otherwise
- :published, ':published', 'published', ':latest-published', 'latest-published' => the last published version if it exists
- a number => a specific published version; integer numbers n will be interpreted as n.0

The following methods take an optional version: argument that allows to retrieve the data specific for that version: #pid, #title, #author, #updated, #created, #published, #metadata_fields, #rdm_data, #metadata, #files, #download. Most of these methods default to using :latest version if omitted. Exceptions to this rule are #rdm (:published) and #download (nil, uses the download api on dataset level by default).

```ruby
ds.title
# => "My new dataset"

ds.title(version: 1)
# => "Preliminary title"

ds.updated
# => 2021-02-11 18:34:47 +0100

ds.updated(version: 1)
# => 2021-02-03 12:05:13 +0100

ds.published
# => 2021-02-11 18:34:47 +0100

ds.published(version: :draft)
# => nil
# (:draft version does not have a publication date)
```

Note that in most cases, entering a non-existent version will throw a Dataverse::VersionError exception. If you want to prevent having to catch the exception in your code, you can use the #version method first to check if the version is valid.

```ruby
ds.title(version: 8.2)
# => Dataverse::VersionError: Version 8.2 does not exist

ds.title(version: 8.2) if ds.version(8.2)
# => nil
```
## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/libis/dataverse_api. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/libis/dataverse_api/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Dataverse API project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/libis/dataverse_api/blob/master/CODE_OF_CONDUCT.md).
