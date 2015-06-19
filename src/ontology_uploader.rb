require_relative '../config.rb'

class OntologyUploader

  attr_reader :restUrl, :apikey, :uploadDate

  def initialize(restUrl, apikey)
    @apikey=apikey
    @restUrl=restUrl
    @uploadDate = Time.now.strftime("%Y-%m-%d")
  end

#http://data.bioontology.org/ontologies/EDAM/latest_submission
  def get_ontology_data(acronym, source)
    # Get the metadata for the ontology we want to upload (depend on the source)

    if source == "ncbo_bioportal"
      # For NCBO it call the last submission

      getSub = "#{bp_url_input}/ontologies/#{acronym}/latest_submission?apikey=#{bp_apikey_input}"
      ontologies_json = JSON.parse(Net::HTTP.get(URI.parse(getSub)))
    end
    return ontologies_json
  end



  #TODO: Pas encore modifié
  def create_ontology(hash)
    # Create a new ontology

    uri = URI.parse(@restUrl)
    http = Net::HTTP.new(uri.host, uri.port)

    req = Net::HTTP::Put.new("/ontologies/#{hash["acronym"]}")
    req['Content-Type'] = "application/json"
    req['Authorization'] = "apikey token=#{@apikey}"

    if (hash["viewingRestriction"] == "private")
      # In case of private ontology
      req.body = { "acronym": hash["acronym"], "name": hash["name"], "group": hash["group"], "hasDomain": hash["hasDomain"], "administeredBy": [@user], "viewingRestriction": "private", "acl": hash["acl"]}.to_json
    else
      req.body = { "acronym": hash["acronym"], "name": hash["name"], "group": hash["group"], "hasDomain": hash["hasDomain"], "administeredBy": [@user]}.to_json
    end

    response = http.start do |http|
      http.request(req)
    end

    return response
  end

#TODO: Pas encore modifié
  def upload_submission(hash, filePath)

    uri = URI.parse(@restUrl)
    http = Net::HTTP.new(uri.host, uri.port)

    req = Net::HTTP::Post.new("/ontologies/#{hash["acronym"]}/submissions")
    req['Content-Type'] = "application/json"
    req['Authorization'] = "apikey token=#{@apikey}"

    if hash.key?("releaseDate") && hash["releaseDate"] != ""
      releaseDate = hash["releaseDate"]
    else
      releaseDate = @uploadDate
    end

    # hasOntologyLanguage: OWL, UMLS, SKOS, OBO
    # status: alpha, beta, production, retired
    req.body = {
        "contact": [{"name": hash["contact"],"email": hash["mail"]}],
        "ontology": "#{@restUrl}/ontologies/#{hash["acronym"]}",
        "hasOntologyLanguage": hash["format"],
        "released": releaseDate,
        "description": hash["description"],
        "status": "production",
        "version": hash["version"],
        "homepage": hash["homepage"],
        "documentation": hash["documentation"],
        "publication": hash["publication"],
        "naturalLanguage": "fr",
        "uploadFilePath": filePath + "/" + hash["uploadPath"]
    }.to_json

    response = http.start do |http|
      http.request(req)
    end

    return response
  end
end