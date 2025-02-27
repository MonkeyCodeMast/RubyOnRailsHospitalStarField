# frozen_string_literal: true

require 'net/http'
require 'json'

module PatientDataHelper
  def get_token
    token = ''
    begin
      uri = URI((ENV['ACCESS_TOKEN_ENDPOINT']).to_s)
      request = Net::HTTP::Post.new(uri.path, {
                                      'Content-Type' => 'application/x-www-form-urlencoded',
                                      'Accept-Encoding' => 'gzip, defalte, br',
                                      'Accept' => '*/*'
                                    })
      request.basic_auth (ENV['ACCESS_TOKEN_AUTH_USERNAME']).to_s, (ENV['ACCESS_TOKEN_AUTH_PASSWORD']).to_s
      request.set_form_data({
                              'grant_type' => 'password',
                              'username' => (ENV['ACCESS_TOKEN_USERNAME']).to_s,
                              'password' => (ENV['ACCESS_TOKEN_PASSWORD']).to_s
                            })
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        result = http.request(request)
        token_response = JSON.parse(result.body)
        token = token_response['access_token']
      end
    rescue StandardError => e
      puts '*****************'
      puts "failed #{e}"
      puts '*****************'
      Rollbar.warning("Error syncing patient data with #{e}")
    end
    token
  end

  def get_diagnostic_report(patient_id, access_token)
    report = ''
    begin
      url = URI("#{ENV['PATIENT_DATA_ENDPOINT']}DiagnosticReport/?patient.identifier=NDHIN%7C#{patient_id}")
      https = Net::HTTP.new(url.host, url.port)
      https.use_ssl = true

      request = Net::HTTP::Get.new(url)
      request['Authorization'] = "Bearer #{access_token}"
      report = https.request(request).read_body
    rescue StandardError => e
      puts '*****************'
      puts "failed #{e}"
      puts '*****************'
      Rollbar.warning("Error syncing patient data with #{e}")
    end
    report
  end

  def get_patient_identifier(user, access_token)
    identifier = ''
    birth_date = user.date_of_birth.strftime('%Y-%m-%d')

    first_name = user.first_name
    last_name = user.last_name

    begin
      url = URI("#{ENV['PATIENT_DATA_ENDPOINT']}Patient?family=#{last_name}&given=#{first_name}&birthdate=#{birth_date}")
      https = Net::HTTP.new(url.host, url.port)
      https.use_ssl = true

      request = Net::HTTP::Get.new(url)
      request['Authorization'] = "Bearer #{access_token}"
      patient_search = https.request(request).read_body

      xmlData = Nokogiri::XML(patient_search)
      xmlData.remove_namespaces!
      patientIdentiers = xmlData.xpath('//Patient//identifier//value/@value')

      patientIdentiers.each do |patientIdentier|
        identifier = patientIdentier.to_s if identifier.length.zero? && patientIdentier.to_s.include?('-')
      end
    rescue StandardError => e
      puts '*****************'
      puts "failed #{e}"
      puts '*****************'
      Rollbar.warning("Error syncing patient data with #{e}")
    end
    identifier
  end

  def get_report_value(report, value_label)
    values = []

    xmlData = Nokogiri::XML(report)
    xmlData.remove_namespaces!
    observations = xmlData.xpath('//DiagnosticReport//contained//Observation')

    observations.each do |observation|
      code_displays = observation.xpath('.//code//coding//display')
      code_displays.each do |display|
        display_text = display.xpath('./@value')
        next unless display_text.to_s.downcase.include?(value_label.downcase)

        value = observation.xpath('.//valueQuantity//value/@value')
        issued = observation.xpath('.//effectiveDateTime/@value')
        values.push({reading_value: value.to_s, date_recorded: issued.to_s})
      end
    end
    values
  end
end
