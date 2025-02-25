require 'csv'

class Vehicle
  def self.opengeodb
    @opengeodb ||= CSV.parse(File.read('config/data/opengeodb.csv'), col_sep: "\t", quote_char: nil, headers: true)
  end

  def self.zip_to_prefix
    @zip_to_prefix ||= JSON.load(Rails.root.join('config/data/zip_to_prefix.json'))
  end

  def self.cars
    @cars ||= JSON.load(Rails.root.join('config/data/cars.json'))
  end

  def self.plates
    @plates ||= JSON.load(Rails.root.join('config/data/plates.json'))
  end

  def self.zip_to_plate_prefix_mapping
    @zip_to_plate_prefix_mapping ||= opengeodb.each_with_object({}) do |entry, hash|
      next unless entry['plz']

      zips = entry['plz'].split(',')
      zips.each { |zip| hash[zip] = entry['kz'] if entry['kz'] }
    end.to_h
  end

  def self.most_often?(matches)
    return nil if matches.blank?

    matches.group_by(&:itself).sort_by { |match, group| group.size }.last[0]
  end

  def self.most_likely_plate?(matches)
    return nil if matches.blank?

    matches.group_by {|registration, _| registration }.sort_by {|_, group| group.sum { |_, probability| probability } / matches.size }.last[0]
  end

  def self.plate?(text)
    text = normalize(text)
    if text =~ plate_regex
      ["#{$1} #{$2} #{$3}", 1.0]
    elsif text =~ relaxed_plate_regex
      ["#{$1}#{$2} #{$3}", 0.8]
    elsif text =~ quirky_mode_plate_regex
      ["#{$1}#{$2} #{$3}", 0.5]
    end
  end

  def self.normalize(text)
    return '' if text.blank?

    tokens = "[ •„.,:;\"'|_+-]"
    left = Regexp.new("^#{tokens}+")
    right = Regexp.new("#{tokens}+$")
    text.gsub(left, '').gsub(right, '').gsub(/\W+/,'-')
  end

  def self.clean_regex
    @clean_regex ||= /^/
  end

  def self.plate_regex
    @plate_regex ||= Regexp.new("^(#{Vehicle.plates.keys.join('|')})-([A-Z]{1,3})-?(\\d{1,4})$")
  end

  def self.relaxed_plate_regex
    @relaxed_plate_regex ||= Regexp.new("^(#{Vehicle.plates.keys.join('|')}):?-?([A-Z]{1,3})-?(\\d{1,4})$")
  end

  def self.quirky_mode_plate_regex
    @quirky_mode_plate_regex ||= Regexp.new("^O?B?(#{Vehicle.plates.keys.join('|')})O?:?-?O?([A-Z]{1,3})-?(\\d{1,4})$")
  end

  def self.district_for_plate_prefix(text)
    prefix = normalize(text)[plate_regex, 1]
    plates[prefix]
  end

  def self.brand?(text)
    text = text.strip.downcase
    res = cars.find { |entry| text.match?(entry['brand'].strip.downcase) }
    return res['brand'] if res.present?

    res = cars.find do |entry|
      (entry['aliases'] || []).find { |ali| text.match?(ali.strip.downcase) }
    end
    return res['brand'] if res.present?

    res = cars.find do |entry|
      entry['models'].find { |model| model =~ /\D+/ && text == model.strip.downcase }
    end
    return res['brand'] if res.present?
  end

  def self.brands
    (car_brands + truck_brands).sort
  end

  def self.car_brands
    cars.map { |entry| entry['brand'] }
  end

  def self.truck_brands
    [
      'MAN',
      'Iveco',
      'CANIA',
      'DAF',
    ]
  end

  def self.models(brand)
    cars.find { |entry| entry['brand'] == brand }.dig('models')
  end

  def self.colors
    @colors ||= [
      'beige',
      'blue',
      'brown',
      'yellow',
      'gray',
      'green',
      'red',
      'black',
      'silver',
      'violet',
      'white',
      'orange',
      'gold',
    ]
  end

  def self.kinds
    @kinds ||= [
      'PKW',
      'LKW',
      'Motorrad',
    ]
  end

  def self.charges
    @charges = [
      'Parken auf einem unbeschilderten Radweg',
      'Parken auf einem Fußgängerüberweg',
      'Parken auf einem Radweg (Zeichen 237)',
      'Parken auf einem Geh- und Radweg (Zeichen 240/241)',
      'Parken auf einer Fahrradstraße (Zeichen 244.1/244.2)',
      'Parken verbotswidrig auf einem Schutzstreifen für den Radverkehr (Zeichen 340)',
      'Parken verbotswidrig auf einem Gehweg',
      'Parken in einem verkehrsberuhigten Bereich (Zeichen 325.1, 325.2) verbotswidrig außerhalb der zum Parken gekennzeichneten Flächen',
      'Parken in einem Fußgängerbereich, der (durch Zeichen 239/242.1, 242.2/250) gesperrt war',
      'Parken in einem Abstand von weniger als 5 Meter vor einem Fußgängerüberweg',
      'Parken weniger als 5 Meter vor/hinter der Kreuzung/Einmündung',
      'Parken im absolutem Haltverbot (Zeichen 283)',
      'Parken unzulässig im eingeschränkten Haltverbot (Zeichen 286)',
      'Parken unzulässig auf einer Sperrfläche (Zeichen 298)',
      'Parken an einer engen/unübersichtlichen Straßenstelle',
      'Parken im Bereich einer scharfen Kurve',
      'Parken unzulässig in der zweiten Reihe',
      'Parkten näher als 10 Meter vor einem Lichtzeichen',
      'Parken vor oder in einer amtlich gekennzeichneten Feuerwehrzufahrt',
      'Parken verbotswidrig im Bereich eines Taxenstandes (Zeichen 229)',
      'Parken verbotswidrig und verhinderten dadurch die Benutzung gekennzeichneter Parkflächen',
      'Parken im Bereich einer Grundstückseinfahrt bzw. -ausfahrt',
      'Parken auf einer schmalen Fahrbahn gegenüber einer Grundstückseinfahrt/Grundstücks-ausfahrt',
      'Parken vor einer Bordsteinabsenkung',
      'Parken verbotswidrig auf der linken Fahrbahnseite/dem linken Seitenstreifen',
      'Parken nicht am rechten Fahrbahnrand',
      'Parken im Fahrraum von Schienenfahrzeugen',
      'Parken links von einer Fahrbahnbegrenzung (Zeichen 295)',
      'Parken in einem Verkehrsbereich, der (durch Zeichen 250/251/253/255/260) gesperrt war',
      'Parken auf einem durch Richtungspfeile (Zeichen 297) gekennzeichneten Fahrbahnteil',
      'Parken innerhalb einer Grenzmarkierung (Zeichen 299) für ein Haltverbot',
      'Parken näher als 10 Meter vor einem Andreaskreuz (Zeichen 201)/Zeichen 205 (Vorfahrt gewähren!)/Zeichen 206 (Halt! Vorfahrt gewähren!) und verdeckten dieses',
      'Parken innerhalb eines Kreisverkehrs (Zeichen 215)',
      'Parken in einem Abstand von weniger als 15 Metern von einem Haltestellenschild',
      'Parken, obwohl zwischen Ihrem Fahrzeug und der Fahrstreifenbegrenzung (Zeichen 295/296) ein Abstand von weniger als 3 Metern verblieb',
      'Parken innerhalb einer Grenzmarkierung (Zeichen 299) für ein Parkverbot',
      'Parken bei zulässigem Gehwegparken (Zeichen 315) nicht auf dem Gehweg',
      'Parkten auf einem Sonderfahrstreifen für Omnibusse des Linienverkehrs (Zeichen 245)',
      'Parken auf einem gekennzeichneten Behindertenparkplatz',
      'Parken mit Verbrenner vor Elektroladesäule',
    ]
  end
end
