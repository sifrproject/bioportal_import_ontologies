require_relative '../config.rb'

class OntologyUploader

  attr_reader :restUrl, :apikey, :user, :uploadDate

  def initialize(restUrl, apikey, user)
    @apikey=apikey
    @restUrl=restUrl
    @user = user
    @uploadDate = Time.now.strftime("%Y-%m-%d")
  end

  def get_submission_data(ontoInfo)
    # Get the metadata for the ontology we want to upload (depend on the source)

    if ontoInfo["source"] == "ncbo_bioportal"
      # For NCBO it call the last submission and get all data from it, except for groups and categories

      getSub = "#{bp_url_input}/ontologies/#{ontoInfo["acronym"]}/latest_submission?apikey=#{bp_apikey_input}"
      hash = JSON.parse(Net::HTTP.get(URI.parse(getSub)))

      ontology_hash = {
          "acronym": ontoInfo["acronym"],
          "name": hash["ontology"]["name"],
          "group": ontoInfo["group"],
          "hasDomain": ontoInfo["hasDomain"],
          "administeredBy": [@user]}

      # Get the contacts for the submission
      contacts = []
      hash["contact"].each do |contact|
        contacts.push({"name": contact["name"], "email": contact["email"]})
      end

      submission_hash = {
          "contact": contacts,
          "ontology": "#{@restUrl}/ontologies/#{ontoInfo["acronym"]}",
          "hasOntologyLanguage": hash["hasOntologyLanguage"],
          "released": hash["released"],
          "description": hash["description"],
          "status": "production",
          "version": hash["version"],
          "homepage": hash["homepage"],
          "documentation": hash["documentation"],
          "publication": hash["publication"],
          "pullLocation": "#{bp_url_input}/ontologies/#{ontoInfo["acronym"]}/submissions/#{hash["submissionId"]}/download?apikey=#{bp_apikey_input}"
      }
    end

    return [ontology_hash, submission_hash]
  end


  def create_ontology(hash)
    # Create a new ontology

    uri = URI.parse(@restUrl)
    http = Net::HTTP.new(uri.host, uri.port)

    req = Net::HTTP::Put.new("/ontologies/#{hash[:acronym]}")
    req['Content-Type'] = "application/json"
    req['Authorization'] = "apikey token=#{@apikey}"

    req.body = hash.to_json

    response = http.start do |http|
      http.request(req)
    end

    return response
  end


  def upload_submission(hash, acronym)
    # Upload a submission

    uri = URI.parse(@restUrl)
    http = Net::HTTP.new(uri.host, uri.port)

    puts hash["acronym"]

    req = Net::HTTP::Post.new("/ontologies/#{acronym}/submissions")
    req['Content-Type'] = "application/json"
    req['Authorization'] = "apikey token=#{@apikey}"

    if hash.key?("releaseDate") && hash["releaseDate"] != ""
      releaseDate = hash["releaseDate"]
    else
      releaseDate = @uploadDate
    end
    
    # status: alpha, beta, production, retired
    req.body = hash.to_json

    response = http.start do |http|
      http.request(req)
    end

    return response
  end
end