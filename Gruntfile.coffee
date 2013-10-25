module.exports = (grunt) ->

  pkg = grunt.file.readJSON 'package.json'

  grunt.initConfig
    pkg: pkg

    'file-creator':
      timezones:
        'src/timezones.coffee': (fs,fd,done) ->
            fs.writeSync fd, '''
              rfile = require 'rfile'
              module.exports = zone_files = {}

            '''
            make_zone_name = (t) -> "../bower_components/tzdata2013g.tar.gz/#{t}"
            for name in 'africa antarctica asia australasia backward etcetera europe factory iso3166.tab leapseconds leap-seconds.list northamerica pacificnew solar87 solar88 solar89 southamerica systemv zone.tab'.split ' '
              file = make_zone_name name
              fs.writeSync fd, """
                zone_files['#{name}'] = rfile '#{file}'

              """
            done()

    browserify:
      dist:
        options:
          transform: ['coffeeify','debowerify','decomponentify', 'deamdify', 'deglobalify','rfileify']
        files:
          'dist/<%= pkg.name %>.js': 'src/main.coffee'

    clean:
      dist: ['lib/', 'dist/']
      modules: ['node_modules/', 'bower_components/']

  grunt.loadNpmTasks 'grunt-file-creator'
  grunt.loadNpmTasks 'grunt-browserify'
  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.registerTask 'default', 'clean:dist file-creator browserify'.split ' '
