Gem::Specification.new do |s|
	s.name        = 'jedict'
	s.version     = '0.2.1'
	s.date        = '2016-10-30'
	s.summary     = "JEDICT custom parser"
	s.description = "Parse the JEDICT and run search operations on the fly or load the entire dictionary in memory"
	s.authors     = ["Sylvain Leclercq"]
	s.email       = 'maisbiensurqueoui@gmail.com'
	s.files       = ["lib/jedict.rb", "assets/jedict"]
	s.homepage    =
		'http://www.github.com/de-passage/jedict'
	s.license       = 'MIT'
	s.add_runtime_dependency 'nokogiri', '~>1.6.8'
end
