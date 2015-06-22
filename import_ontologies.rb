#!/usr/bin/ruby

require 'net/http'
require 'json'
require_relative 'config.rb'
require_relative 'src/ontology_uploader.rb'

#http://data.bioontology.org/ontologies/EDAM/latest_submission


#restUrl = bp_url_input
#restUrl = "http://data.stageportal.lirmm.fr"
#restUrl = "http://data.agroportal.lirmm.fr"
#apikey = bp_apikey_input
user = "admin"


jsonImport = "import_array.json"

# The folder where the ontologies are:
ontologiesPath = "/srv/data/ontologies"


ontologyUploader = OntologyUploader.new(bp_url_output, bp_apikey_output, user)

file = File.read(jsonImport)
ontologiesArray = JSON.parse(file)


ontologiesArray.each do |onto|
  puts onto["acronym"]
  ontoData = ontologyUploader.get_submission_data(onto)
    # Get an array with a hash with infos to create the ontology and another hash with info to import the submission
  puts ontologyUploader.create_ontology(ontoData[0])
  puts ontologyUploader.upload_submission(ontoData[1], onto["acronym"])
end