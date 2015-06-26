require_relative '../config.rb'

class OntologyUploader

  attr_reader :restUrl, :apikey, :user, :uploadDate

  def initialize(restUrl, apikey, user)
    @apikey=apikey
    @restUrl=restUrl
    @user = user
    @uploadDate = Time.now.strftime("%Y-%m-%d")
  end

  def upload_ontology(jsonInput)
    begin
      # Get an array with a hash with infos to create the ontology and another hash with info to import the submission
      # The way of retrieving infos depends on the source
      ontoData = get_submission_data(jsonInput)
    rescue StandardError => err
      puts err
      retry
    end

    # Create the ontology, raise a Net::HTTPConflict if already existing
    begin
      puts ontoResult = create_ontology(ontoData[0])
    rescue err
      puts err
      retry
    end until ontoResult == "Net::HTTPCreated" || ontoResult == "Net::HTTPConflict"

    # Upload the submission
    begin
      puts subResult = upload_submission(ontoData[1], jsonInput["acronym"])
    rescue StandardError => err
      puts err
      retry
    end until subResult == "Net::HTTPCreated"
  end


  def get_submission_data(jsonInput)
    # Get the metadata for the ontology we want to upload (depend on the source)
    # It returns an array with 2 hash : one to create the ontology and the other for the submission
    if jsonInput["source"] == "ncbo_bioportal"
      resultArray = get_info_from_bioportal(jsonInput)
    elsif jsonInput["source"] == "cropontology"
      resultArray = get_info_from_cropontology(jsonInput)
    else
      resultArray = get_info_from_json(jsonInput)
    end

    return resultArray
  end


  def get_info_from_json(jsonInput)
    # Create the JSON used to create ontology and upload submission

    getSub = "#{bp_url_input}/ontologies/#{jsonInput["acronym"]}/latest_submission?apikey=#{bp_apikey_input}"
    hash = JSON.parse(Net::HTTP.get(URI.parse(getSub)))

    ontology_hash = {
        "acronym": jsonInput["acronym"],
        "name": jsonInput["name"],
        "group": jsonInput["group"],
        "hasDomain": jsonInput["hasDomain"],
        "administeredBy": [@user]}

    if jsonInput.key?("releaseDate") && jsonInput["releaseDate"] != ""
      releaseDate = jsonInput["releaseDate"]
    else
      releaseDate = @uploadDate
    end

    submission_hash = {
        "contact": jsonInput["contact"],
        "ontology": "#{@restUrl}/ontologies/#{jsonInput["acronym"]}",
        "hasOntologyLanguage": jsonInput["hasOntologyLanguage"],
        "released": releaseDate,
        "description": jsonInput["description"],
        "status": "production",
        "version": jsonInput["version"],
        "homepage": jsonInput["homepage"],
        "documentation": jsonInput["documentation"],
        "publication": jsonInput["publication"],
        "pullLocation": jsonInput["pullLocation"]
    }

    return [ontology_hash, submission_hash]
  end

  def get_info_from_cropontology(jsonInput)
    # Create the JSON used to create ontology and upload submission

    ontology_hash = {
        "acronym": jsonInput["acronym"],
        "name": jsonInput["name"],
        "group": jsonInput["group"],
        "hasDomain": jsonInput["hasDomain"],
        "administeredBy": [@user]}

    if jsonInput.key?("releaseDate") && jsonInput["releaseDate"] != ""
      releaseDate = jsonInput["releaseDate"]
    else
      releaseDate = @uploadDate
    end

    oboFilePath = "ontology_files/#{jsonInput["acronym"]}.obo"
    oboFile = Net::HTTP.get(URI.parse(jsonInput["download"]))
    File.open(oboFilePath, "w") { |f|
      f.write(oboFile)
    }

    submission_hash = {
        "contact": jsonInput["contact"],
        "ontology": "#{@restUrl}/ontologies/#{jsonInput["acronym"]}",
        "hasOntologyLanguage": jsonInput["hasOntologyLanguage"],
        "released": releaseDate,
        "description": jsonInput["description"],
        "status": "production",
        "version": jsonInput["version"],
        "homepage": jsonInput["homepage"],
        "documentation": jsonInput["documentation"],
        "publication": jsonInput["publication"],
        "uploadFilePath": oboFilePath
    }

    puts submission_hash

    return [ontology_hash, submission_hash]
  end


  def get_info_from_bioportal(ontoInfo)
    # For NCBO it call the last submission and get all data from it, except for groups and categories
    getSub = "#{bp_url_input}/ontologies/#{ontoInfo["acronym"]}/latest_submission?apikey=#{bp_apikey_input}&include=all"
    hash = JSON.parse(Net::HTTP.get(URI.parse(getSub)))

    if hash["submissionStatus"].include? "ERROR_RDF"
      # Check if there is an ERROR_RDF in the submission and get infos from previous submission if yes
      subId = hash["submissionId"].to_i
      subId = subId - 1
      uploadArray = get_info_from_sub(ontoInfo, subId)
    else
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
          "status": hash["status"],
          "version": hash["version"],
          "homepage": hash["homepage"],
          "documentation": hash["documentation"],
          "publication": hash["publication"],
          "pullLocation": "#{bp_url_input}/ontologies/#{ontoInfo["acronym"]}/submissions/#{hash["submissionId"]}/download?apikey=#{bp_apikey_input}"
      }

      uploadArray = [ontology_hash, submission_hash]
    end

    puts uploadArray
    return uploadArray
  end

  def get_info_from_sub(ontoInfo, subId)
    # Get infos from previous submission if there is an ERROR_RDF in the submission

    getSub = "#{bp_url_input}/ontologies/#{ontoInfo["acronym"]}/submissions/#{subId}?apikey=#{bp_apikey_input}&include=all"
    hash = JSON.parse(Net::HTTP.get(URI.parse(getSub)))

    if hash["submissionStatus"].include? "ERROR_RDF"
      subId = hash["submissionId"].to_i
      subId = subId - 1
      puts subId
      uploadArray = get_info_from_sub(ontoInfo, subId)
    else
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
          "status": hash["status"],
          "version": hash["version"],
          "homepage": hash["homepage"],
          "documentation": hash["documentation"],
          "publication": hash["publication"],
          "pullLocation": "#{bp_url_input}/ontologies/#{ontoInfo["acronym"]}/submissions/#{hash["submissionId"]}/download?apikey=#{bp_apikey_input}"
      }
      uploadArray = [ontology_hash, submission_hash]
    end

    return uploadArray
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

    return response.class.to_s
  end


  def upload_submission(hash, acronym)
    # Upload a submission

    uri = URI.parse(@restUrl)
    http = Net::HTTP.new(uri.host, uri.port)

    req = Net::HTTP::Post.new("/ontologies/#{acronym}/submissions")
    req['Content-Type'] = "application/json"
    req['Authorization'] = "apikey token=#{@apikey}"

    # status: alpha, beta, production, retired
    req.body = hash.to_json

    response = http.start do |http|
      http.request(req)
    end

    return response.class.to_s
  end
end