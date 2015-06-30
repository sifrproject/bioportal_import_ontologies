#!/usr/bin/ruby

require 'net/http'
require 'net/scp'
require 'json'
require_relative 'config.rb'
require_relative 'src/ontology_uploader.rb'


jsonImport = "import_array.json"


ontologyUploader = OntologyUploader.new(bp_url_output, bp_apikey_output, bp_user_output)

file = File.read(jsonImport)
ontologiesArray = JSON.parse(file)


ontologiesArray.each do |onto|
  puts onto["acronym"]
  ontologyUploader.upload_ontology(onto)
end