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
      uploadHash = get_submission_data(jsonInput)
    rescue StandardError => err
      puts err
      retry
    end

    puts uploadHash

    # Create the ontology, Net::HTTPConflict is raised if already existing
    begin
      puts ontoResult = create_ontology(uploadHash[:ontology_hash])
    rescue err
      puts err
      retry
    end until ontoResult == "Net::HTTPCreated" || ontoResult == "Net::HTTPConflict"

    # Upload the submission
    begin
      puts subResult = upload_submission(uploadHash[:submission_hash], jsonInput["acronym"])
    rescue StandardError => err
      puts err
      retry
    end until subResult == "Net::HTTPCreated"
  end


  def get_submission_data(jsonInput)
    # Get the metadata for the ontology we want to upload (depend on the source : bioportal,cropontology or informations in the JSON)
    # It returns an array with 2 hash : one to create the ontology and the other for the submission
    if jsonInput["source"] == "bioportal"
      uploadHash = get_info_from_bioportal(jsonInput)
    elsif jsonInput["source"] == "cropontology"
      uploadHash = get_info_from_cropontology(jsonInput)
    else
      uploadHash = get_info_from_json(jsonInput)
    end
    return uploadHash
  end


  def get_info_from_json(jsonInput)
    # Create the JSON used to create ontology and upload submission
    # Can be used for ontologies that have no source and that are uploaded on the appliance (then you just need to give the uploadFilePath)

    # Generate the 2 hash needed to upload the ontology : one to create the ontology, the other to upload the submission
    # Those hash are incomplete and still need the upload file path or URL pull location
    uploadHash = generate_submission_from_json(jsonInput)

    # Check if we are pulling the ontology from an URL (using pullLocation) or from local
    if jsonInput.key?("pullLocation") && jsonInput["pullLocation"] != ""
      uploadHash[:submission_hash]["pullLocation"] = jsonInput["pullLocation"]
    elsif jsonInput.key?("uploadFilePath") && jsonInput["uploadFilePath"] != ""
      # If there is not pullLocation key then it is looking for a uploadFilePath key to upload from a local file

      regexGetFilename = jsonInput["uploadFilePath"].scan(/([^\/]*)$/)

      ontoRemotePath = "/tmp/#{regexGetFilename[0][0]}"
      Net::SCP.start(server_hostname, server_username, :password => server_password) do |scp|
        scp.upload(jsonInput["uploadFilePath"], ontoRemotePath)
      end

      uploadHash[:submission_hash]["uploadFilePath"] = ontoRemotePath
    end

    return uploadHash
  end

  def get_info_from_cropontology(jsonInput)
    # Create the JSON used to create ontology and upload submission for cropontology upload

    # Generate the 2 hash needed to upload the ontology : one to create the ontology, the other to upload the submission
    # Those hash are incomplete and still need the upload file path
    uploadHash = generate_submission_from_json(jsonInput)

    # BioPortal don't manage to pull ontologies directly from cropontology.org
    # so we need to download the ontology, upload it to the appliance and then upload it in bioportal

    oboLocalPath = "#{File.dirname(__FILE__)}/../ontology_files/#{jsonInput["acronym"]}.obo"
    oboFile = Net::HTTP.get(URI.parse(jsonInput["pullLocation"]))
    File.open(oboLocalPath, "w") { |f|
      f.write(oboFile)
    }

    oboRemotePath = "/tmp/#{jsonInput["acronym"]}.obo"
    Net::SCP.start(server_hostname, server_username, :password => server_password) do |scp|
      scp.upload(oboLocalPath, oboRemotePath)
    end

    uploadHash[:submission_hash]["uploadFilePath"] = oboRemotePath

    return uploadHash
  end

  
  def get_info_from_bioportal(ontoInfo)
    # For NCBO it call the last submission and get all data from it, except for groups and categories
    # If last submission has and ERROR_RDF it calls the previous

    getSub = "#{bp_url_input}/ontologies/#{ontoInfo["acronym"]}/latest_submission?apikey=#{bp_apikey_input}&include=all"
    hash = JSON.parse(Net::HTTP.get(URI.parse(getSub)))

    if hash["submissionStatus"].include? "ERROR_RDF"
      # Check if there is an ERROR_RDF in the submission and get infos from previous submission if yes
      subId = hash["submissionId"].to_i
      subId = subId - 1
      uploadHash = get_info_from_sub(ontoInfo, subId)
    else
      ontology_hash = {
          "acronym"=> ontoInfo["acronym"],
          "name"=> hash["ontology"]["name"],
          "group"=> ontoInfo["group"],
          "hasDomain"=> ontoInfo["hasDomain"],
          "administeredBy"=> [@user]}

      # Get the contacts for the submission
      contacts = []
      hash["contact"].each do |contact|
        contacts.push({"name"=> contact["name"], "email"=> contact["email"]})
      end

      submission_hash = {
          "contact"=> contacts,
          "ontology"=> "#{@restUrl}/ontologies/#{ontoInfo["acronym"]}",
          "hasOntologyLanguage"=> hash["hasOntologyLanguage"],
          "released"=> hash["released"],
          "description"=> hash["description"],
          "status"=> hash["status"],
          "version"=> hash["version"],
          "homepage"=> hash["homepage"],
          "documentation"=> hash["documentation"],
          "publication"=> hash["publication"],
          "pullLocation"=> "#{bp_url_input}/ontologies/#{ontoInfo["acronym"]}/submissions/#{hash["submissionId"]}/download?apikey=#{bp_apikey_input}"
      }

      uploadHash = {:ontology_hash=> ontology_hash, :submission_hash=> submission_hash}
    end

    return uploadHash
  end

  def get_info_from_sub(ontoInfo, subId)
    # Get infos from previous submission if there is an ERROR_RDF in the actual submission

    getSub = "#{bp_url_input}/ontologies/#{ontoInfo["acronym"]}/submissions/#{subId}?apikey=#{bp_apikey_input}&include=all"
    hash = JSON.parse(Net::HTTP.get(URI.parse(getSub)))

    if hash["submissionStatus"].include? "ERROR_RDF"
      subId = hash["submissionId"].to_i
      subId = subId - 1
      puts subId
      uploadHash = get_info_from_sub(ontoInfo, subId)
    else
      ontology_hash = {
          "acronym"=> ontoInfo["acronym"],
          "name"=> hash["ontology"]["name"],
          "group"=> ontoInfo["group"],
          "hasDomain"=> ontoInfo["hasDomain"],
          "administeredBy"=> [@user]}

      # Get the contacts for the submission
      contacts = []
      hash["contact"].each do |contact|
        contacts.push({"name"=> contact["name"], "email"=> contact["email"]})
      end

      submission_hash = {
          "contact"=> contacts,
          "ontology"=> "#{@restUrl}/ontologies/#{ontoInfo["acronym"]}",
          "hasOntologyLanguage"=> hash["hasOntologyLanguage"],
          "released"=> hash["released"],
          "description"=> hash["description"],
          "status"=> hash["status"],
          "version"=> hash["version"],
          "homepage"=> hash["homepage"],
          "documentation"=> hash["documentation"],
          "publication"=> hash["publication"],
          "pullLocation"=> "#{bp_url_input}/ontologies/#{ontoInfo["acronym"]}/submissions/#{hash["submissionId"]}/download?apikey=#{bp_apikey_input}"
      }
      uploadHash = {:ontology_hash=> ontology_hash, :submission_hash=> submission_hash}
    end

    return uploadHash
  end

  def generate_submission_from_json(jsonInput)
    # Create the JSON used to create ontology and upload submission for cropontology upload

    ontology_hash = {
        "acronym"=> jsonInput["acronym"],
        "name"=> jsonInput["name"],
        "group"=> jsonInput["group"],
        "hasDomain"=> jsonInput["hasDomain"],
        "administeredBy"=> [@user]}

    # Check if a release date is given, if not put the actual date
    if jsonInput.key?("releaseDate") && jsonInput["releaseDate"] != ""
      releaseDate = jsonInput["releaseDate"]
    else
      releaseDate = @uploadDate
    end

    # Check if a status is given (alpha, beta, production, retired), if not put production as status
    if jsonInput.key?("status") && jsonInput["status"] != ""
      status = jsonInput["status"]
    else
      status = "production"
    end

    submission_hash = {
        "contact"=> jsonInput["contact"],
        "ontology"=> "#{@restUrl}/ontologies/#{jsonInput["acronym"]}",
        "hasOntologyLanguage"=> jsonInput["hasOntologyLanguage"],
        "prefLabelProperty"=> jsonInput["prefLabelProperty"],
        "altLabelProperty"=> jsonInput["altLabelProperty"],
        "definitionProperty"=> jsonInput["definitionProperty"],
        "authorProperty"=> jsonInput["authorProperty"],
        "released"=> releaseDate,
        "description"=> jsonInput["description"],
        "status"=> status,
        "version"=> jsonInput["version"],
        "homepage"=> jsonInput["homepage"],
        "documentation"=> jsonInput["documentation"],
        "publication"=> jsonInput["publication"]
    }

    return {:ontology_hash=> ontology_hash, :submission_hash=> submission_hash}
  end

  def create_ontology(hash)
    # Create a new ontology

    uri = URI.parse(@restUrl)
    http = Net::HTTP.new(uri.host, uri.port)

    req = Net::HTTP::Put.new("/ontologies/#{hash["acronym"]}")
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