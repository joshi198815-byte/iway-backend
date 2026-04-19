class GuatemalaDepartment {
  final String name;
  final List<String> municipalities;
  final List<String> zones;

  const GuatemalaDepartment({
    required this.name,
    this.municipalities = const [],
    this.zones = const [],
  });
}

class UsStateCatalog {
  final String name;
  final List<String> cities;

  const UsStateCatalog({required this.name, required this.cities});
}

const List<String> supportedCountries = ['Guatemala', 'Estados Unidos'];

const List<GuatemalaDepartment> guatemalaDepartments = [
  GuatemalaDepartment(name: 'Alta Verapaz', municipalities: ['Cobán', 'San Pedro Carchá', 'Chisec', 'Tactic']),
  GuatemalaDepartment(name: 'Baja Verapaz', municipalities: ['Salamá', 'Rabinal', 'Cubulco', 'Purulhá']),
  GuatemalaDepartment(name: 'Chimaltenango', municipalities: ['Chimaltenango', 'Patzún', 'Tecpán Guatemala', 'Pochuta']),
  GuatemalaDepartment(name: 'Chiquimula', municipalities: ['Chiquimula', 'Esquipulas', 'Ipala', 'Jocotán']),
  GuatemalaDepartment(name: 'El Progreso', municipalities: ['Guastatoya', 'Sanarate', 'Morazán', 'Sansare']),
  GuatemalaDepartment(name: 'Escuintla', municipalities: ['Escuintla', 'Santa Lucía Cotzumalguapa', 'Tiquisate', 'Puerto San José']),
  GuatemalaDepartment(
    name: 'Guatemala',
    municipalities: ['Guatemala', 'Mixco', 'Villa Nueva', 'Villa Canales', 'San Miguel Petapa', 'Chinautla', 'Santa Catarina Pinula', 'Fraijanes'],
    zones: ['Zona 1', 'Zona 2', 'Zona 3', 'Zona 4', 'Zona 5', 'Zona 6', 'Zona 7', 'Zona 8', 'Zona 9', 'Zona 10', 'Zona 11', 'Zona 12', 'Zona 13', 'Zona 14', 'Zona 15', 'Zona 16', 'Zona 17', 'Zona 18', 'Zona 19', 'Zona 21', 'Zona 24', 'Zona 25'],
  ),
  GuatemalaDepartment(name: 'Huehuetenango', municipalities: ['Huehuetenango', 'Jacaltenango', 'Malacatancito', 'Barillas']),
  GuatemalaDepartment(name: 'Izabal', municipalities: ['Puerto Barrios', 'Morales', 'Los Amates', 'Livingston']),
  GuatemalaDepartment(name: 'Jalapa', municipalities: ['Jalapa', 'Monjas', 'Mataquescuintla', 'San Pedro Pinula']),
  GuatemalaDepartment(name: 'Jutiapa', municipalities: ['Jutiapa', 'Asunción Mita', 'El Progreso', 'Quesada']),
  GuatemalaDepartment(name: 'Petén', municipalities: ['Flores', 'San Benito', 'Santa Elena', 'Sayaxché']),
  GuatemalaDepartment(name: 'Quetzaltenango', municipalities: ['Quetzaltenango', 'Coatepeque', 'Olintepeque', 'Salcajá']),
  GuatemalaDepartment(name: 'Quiché', municipalities: ['Santa Cruz del Quiché', 'Chichicastenango', 'Joyabaj', 'Nebaj']),
  GuatemalaDepartment(name: 'Retalhuleu', municipalities: ['Retalhuleu', 'Champerico', 'San Sebastián', 'Nuevo San Carlos']),
  GuatemalaDepartment(name: 'Sacatepéquez', municipalities: ['Antigua Guatemala', 'Ciudad Vieja', 'Jocotenango', 'San Lucas Sacatepéquez']),
  GuatemalaDepartment(name: 'San Marcos', municipalities: ['San Marcos', 'Malacatán', 'San Pedro Sacatepéquez', 'Ocós']),
  GuatemalaDepartment(name: 'Santa Rosa', municipalities: ['Cuilapa', 'Barberena', 'Oratorio', 'Taxisco']),
  GuatemalaDepartment(name: 'Sololá', municipalities: ['Sololá', 'Panajachel', 'Santiago Atitlán', 'San Lucas Tolimán']),
  GuatemalaDepartment(name: 'Suchitepéquez', municipalities: ['Mazatenango', 'Patulul', 'Samayac', 'San Bernardino']),
  GuatemalaDepartment(name: 'Totonicapán', municipalities: ['Totonicapán', 'Momostenango', 'San Cristóbal Totonicapán', 'Santa Lucía La Reforma']),
  GuatemalaDepartment(name: 'Zacapa', municipalities: ['Zacapa', 'Gualán', 'Teculután', 'Estanzuela']),
];

const List<UsStateCatalog> usStatesCatalog = [
  UsStateCatalog(name: 'Alabama', cities: ['Birmingham', 'Montgomery', 'Mobile', 'Huntsville']),
  UsStateCatalog(name: 'Alaska', cities: ['Anchorage', 'Fairbanks', 'Juneau', 'Wasilla']),
  UsStateCatalog(name: 'Arizona', cities: ['Phoenix', 'Tucson', 'Mesa', 'Glendale']),
  UsStateCatalog(name: 'Arkansas', cities: ['Little Rock', 'Fort Smith', 'Fayetteville', 'Springdale']),
  UsStateCatalog(name: 'California', cities: ['Los Angeles', 'San Diego', 'San José', 'Sacramento', 'Fresno']),
  UsStateCatalog(name: 'Colorado', cities: ['Denver', 'Colorado Springs', 'Aurora', 'Fort Collins']),
  UsStateCatalog(name: 'Connecticut', cities: ['Bridgeport', 'New Haven', 'Hartford', 'Stamford']),
  UsStateCatalog(name: 'Delaware', cities: ['Wilmington', 'Dover', 'Newark', 'Middletown']),
  UsStateCatalog(name: 'Florida', cities: ['Miami', 'Doral', 'Orlando', 'Tampa', 'Jacksonville', 'Hialeah']),
  UsStateCatalog(name: 'Georgia', cities: ['Atlanta', 'Savannah', 'Augusta', 'Columbus']),
  UsStateCatalog(name: 'Hawái', cities: ['Honolulu', 'Hilo', 'Kailua', 'Pearl City']),
  UsStateCatalog(name: 'Idaho', cities: ['Boise', 'Meridian', 'Nampa', 'Idaho Falls']),
  UsStateCatalog(name: 'Illinois', cities: ['Chicago', 'Aurora', 'Naperville', 'Joliet']),
  UsStateCatalog(name: 'Indiana', cities: ['Indianapolis', 'Fort Wayne', 'Evansville', 'South Bend']),
  UsStateCatalog(name: 'Iowa', cities: ['Des Moines', 'Cedar Rapids', 'Davenport', 'Sioux City']),
  UsStateCatalog(name: 'Kansas', cities: ['Wichita', 'Overland Park', 'Kansas City', 'Topeka']),
  UsStateCatalog(name: 'Kentucky', cities: ['Louisville', 'Lexington', 'Bowling Green', 'Owensboro']),
  UsStateCatalog(name: 'Luisiana', cities: ['New Orleans', 'Baton Rouge', 'Shreveport', 'Lafayette']),
  UsStateCatalog(name: 'Maine', cities: ['Portland', 'Lewiston', 'Bangor', 'South Portland']),
  UsStateCatalog(name: 'Maryland', cities: ['Baltimore', 'Silver Spring', 'Frederick', 'Rockville']),
  UsStateCatalog(name: 'Massachusetts', cities: ['Boston', 'Worcester', 'Springfield', 'Cambridge']),
  UsStateCatalog(name: 'Michigan', cities: ['Detroit', 'Grand Rapids', 'Warren', 'Lansing']),
  UsStateCatalog(name: 'Minnesota', cities: ['Minneapolis', 'Saint Paul', 'Rochester', 'Bloomington']),
  UsStateCatalog(name: 'Misisipi', cities: ['Jackson', 'Gulfport', 'Southaven', 'Hattiesburg']),
  UsStateCatalog(name: 'Misuri', cities: ['Kansas City', 'St. Louis', 'Springfield', 'Columbia']),
  UsStateCatalog(name: 'Montana', cities: ['Billings', 'Missoula', 'Bozeman', 'Great Falls']),
  UsStateCatalog(name: 'Nebraska', cities: ['Omaha', 'Lincoln', 'Bellevue', 'Grand Island']),
  UsStateCatalog(name: 'Nevada', cities: ['Las Vegas', 'Henderson', 'Reno', 'North Las Vegas']),
  UsStateCatalog(name: 'New Hampshire', cities: ['Manchester', 'Nashua', 'Concord', 'Dover']),
  UsStateCatalog(name: 'New Jersey', cities: ['Newark', 'Jersey City', 'Paterson', 'Elizabeth']),
  UsStateCatalog(name: 'New Mexico', cities: ['Albuquerque', 'Las Cruces', 'Rio Rancho', 'Santa Fe']),
  UsStateCatalog(name: 'New York', cities: ['New York City', 'Buffalo', 'Rochester', 'Yonkers']),
  UsStateCatalog(name: 'North Carolina', cities: ['Charlotte', 'Raleigh', 'Greensboro', 'Durham']),
  UsStateCatalog(name: 'North Dakota', cities: ['Fargo', 'Bismarck', 'Grand Forks', 'Minot']),
  UsStateCatalog(name: 'Ohio', cities: ['Columbus', 'Cleveland', 'Cincinnati', 'Toledo']),
  UsStateCatalog(name: 'Oklahoma', cities: ['Oklahoma City', 'Tulsa', 'Norman', 'Broken Arrow']),
  UsStateCatalog(name: 'Oregón', cities: ['Portland', 'Eugene', 'Salem', 'Gresham']),
  UsStateCatalog(name: 'Pensilvania', cities: ['Philadelphia', 'Pittsburgh', 'Allentown', 'Erie']),
  UsStateCatalog(name: 'Rhode Island', cities: ['Providence', 'Warwick', 'Cranston', 'Pawtucket']),
  UsStateCatalog(name: 'South Carolina', cities: ['Charleston', 'Columbia', 'North Charleston', 'Greenville']),
  UsStateCatalog(name: 'South Dakota', cities: ['Sioux Falls', 'Rapid City', 'Aberdeen', 'Brookings']),
  UsStateCatalog(name: 'Tennessee', cities: ['Nashville', 'Memphis', 'Knoxville', 'Chattanooga']),
  UsStateCatalog(name: 'Texas', cities: ['Houston', 'Dallas', 'Austin', 'San Antonio', 'Fort Worth']),
  UsStateCatalog(name: 'Utah', cities: ['Salt Lake City', 'West Valley City', 'Provo', 'Ogden']),
  UsStateCatalog(name: 'Vermont', cities: ['Burlington', 'South Burlington', 'Rutland', 'Montpelier']),
  UsStateCatalog(name: 'Virginia', cities: ['Virginia Beach', 'Norfolk', 'Richmond', 'Arlington']),
  UsStateCatalog(name: 'Washington', cities: ['Seattle', 'Spokane', 'Tacoma', 'Vancouver']),
  UsStateCatalog(name: 'West Virginia', cities: ['Charleston', 'Huntington', 'Morgantown', 'Parkersburg']),
  UsStateCatalog(name: 'Wisconsin', cities: ['Milwaukee', 'Madison', 'Green Bay', 'Kenosha']),
  UsStateCatalog(name: 'Wyoming', cities: ['Cheyenne', 'Casper', 'Laramie', 'Gillette']),
  UsStateCatalog(name: 'Distrito de Columbia', cities: ['Washington D. C.']),
];

Map<String, List<String>> get supportedRegionsByCountry => {
  'Guatemala': guatemalaDepartments.map((item) => item.name).toList(),
  'Estados Unidos': usStatesCatalog.map((item) => item.name).toList(),
};

List<String> availableRegionsForCountry(String country) {
  if (country == 'Guatemala') {
    return guatemalaDepartments.map((item) => item.name).toList();
  }
  return usStatesCatalog.map((item) => item.name).toList();
}

List<String> municipalitiesForDepartment(String department) {
  return guatemalaDepartments.firstWhere(
    (item) => item.name == department,
    orElse: () => const GuatemalaDepartment(name: ''),
  ).municipalities;
}

List<String> zonesForDepartment(String department) {
  return guatemalaDepartments.firstWhere(
    (item) => item.name == department,
    orElse: () => const GuatemalaDepartment(name: ''),
  ).zones;
}

List<String> citiesForUsState(String state) {
  return usStatesCatalog.firstWhere(
    (item) => item.name == state,
    orElse: () => const UsStateCatalog(name: '', cities: []),
  ).cities;
}
