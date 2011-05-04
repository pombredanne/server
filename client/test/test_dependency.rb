#
# Test tpkg's ability to resolve dependencies
#

require "./#{File.dirname(__FILE__)}/tpkgtest"

# Give ourself access to some Tpkg variables
class Tpkg
  attr_reader :available_packages_cache
end

class TpkgDependencyTests < Test::Unit::TestCase
  include TpkgTests
  
  def setup
    Tpkg::set_prompt(false)
    
    # temp dir that will automatically get deleted at end of test run, can be
    # used for storing packages
    @tempoutdir = Dir.mktmpdir('tempoutdir')
    @pkgfiles = []
    # a depends on b, and c >= 1.1, <= 1.2
    @pkgfiles << make_package(:output_directory => @tempoutdir, :change => { 'name' => 'a' }, :remove => ['operatingsystem', 'architecture'], :dependencies => {'b' => {}, 'c' => {'minimum_version' => '1.1', 'maximum_version' => '1.2'}})
    # generic b for all OSs
    # These two b packages will end up with the same filename, so we
    # manually rename this one
    bpkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'b' }, :remove => ['operatingsystem', 'architecture'])
    bpkgnew = bpkg + '.generic'
    File.rename(bpkg, bpkgnew)
    @pkgfiles << bpkgnew
    # b specific to this OS (should prefer this one)
    @pkgfiles << make_package(:output_directory => @tempoutdir, :change => { 'name' => 'b', 'operatingsystem' => Tpkg::get_os }, :remove => ['architecture'])
    # c 1.0 to 1.3, a's dep should result in c-1.2 getting picked
    @pkgfiles << make_package(:output_directory => @tempoutdir, :change => { 'name' => 'c', 'version' => '1.0' }, :remove => ['operatingsystem', 'architecture'], :dependencies => {'d' => {'minimum_version' => '1.0', 'maximum_version' => '1.0'}})
    @pkgfiles << make_package(:output_directory => @tempoutdir, :change => { 'name' => 'c', 'version' => '1.1' }, :remove => ['operatingsystem', 'architecture'], :dependencies => {'d' => {'minimum_version' => '1.1', 'maximum_version' => '1.1'}})
    @pkgfiles << make_package(:output_directory => @tempoutdir, :change => { 'name' => 'c', 'version' => '1.2' }, :remove => ['operatingsystem', 'architecture'], :dependencies => {'d' => {'minimum_version' => '1.2', 'maximum_version' => '1.2'}})
    @pkgfiles << make_package(:output_directory => @tempoutdir, :change => { 'name' => 'c', 'version' => '1.3' }, :remove => ['operatingsystem', 'architecture'], :dependencies => {'d' => {'minimum_version' => '1.3', 'maximum_version' => '1.3'}})
    # d 1.0 to 1.3, c's dep should result in d-1.2 getting picked
    @pkgfiles << make_package(:output_directory => @tempoutdir, :change => { 'name' => 'd', 'version' => '1.0' }, :remove => ['operatingsystem', 'architecture'])
    @pkgfiles << make_package(:output_directory => @tempoutdir, :change => { 'name' => 'd', 'version' => '1.1' }, :remove => ['operatingsystem', 'architecture'])
    @pkgfiles << make_package(:output_directory => @tempoutdir, :change => { 'name' => 'd', 'version' => '1.2' }, :remove => ['operatingsystem', 'architecture'])
    @pkgfiles << make_package(:output_directory => @tempoutdir, :change => { 'name' => 'd', 'version' => '1.3' }, :remove => ['operatingsystem', 'architecture'])
  end
  
  def test_package_meets_requirement
    #
    # Test version handling
    #
    
    pkgfile = make_package(:output_directory => @tempoutdir, :remove => ['operatingsystem', 'architecture'])
    metadata = Tpkg::metadata_from_package(pkgfile)
    pkg = { :metadata => metadata, :source => pkgfile }
    req = { :name => 'testpkg' }
    
    # Below minimum version w/o package version
    req[:minimum_version] = '2.0'
    req[:maximum_version] = '3.0'
    req.delete(:minimum_package_version)
    req.delete(:maximum_package_version)
    assert(!Tpkg::package_meets_requirement?(pkg, req))
    # Below minimum version w/ package version
    req[:minimum_package_version] = '1.0'
    req[:maximum_package_version] = '2.0'
    assert(!Tpkg::package_meets_requirement?(pkg, req))
    # At minimum version w/o package version
    req[:minimum_version] = '1.0'
    req[:maximum_version] = '2.0'
    req.delete(:minimum_package_version)
    req.delete(:maximum_package_version)
    assert(Tpkg::package_meets_requirement?(pkg, req))
    # At minimum version w/ package version
    req[:minimum_package_version] = '1.0'
    req[:maximum_package_version] = '2.0'
    assert(Tpkg::package_meets_requirement?(pkg, req))
    # In middle of range w/o package version
    req[:minimum_version] = '0.5'
    req[:maximum_version] = '2.0'
    req.delete(:minimum_package_version)
    req.delete(:maximum_package_version)
    assert(Tpkg::package_meets_requirement?(pkg, req))
    # In middle of range w/ package version
    req[:minimum_version] = '0.5'
    req[:maximum_version] = '2.0'
    req[:minimum_package_version] = '0.5'
    req[:maximum_package_version] = '2.0'
    assert(Tpkg::package_meets_requirement?(pkg, req))
    # At maximum version w/o package version
    req[:minimum_version] = '0.5'
    req[:maximum_version] = '1.0'
    req.delete(:minimum_package_version)
    req.delete(:maximum_package_version)
    assert(Tpkg::package_meets_requirement?(pkg, req))
    # At maximum version w/ package version
    req[:minimum_version] = '0.5'
    req[:maximum_version] = '1.0'
    req[:minimum_package_version] = '0.5'
    req[:maximum_package_version] = '1.0'
    assert(Tpkg::package_meets_requirement?(pkg, req))
    # Above maximum version w/o package version
    req[:minimum_version] = '0.1'
    req[:maximum_version] = '0.5'
    req.delete(:minimum_package_version)
    req.delete(:maximum_package_version)
    assert(!Tpkg::package_meets_requirement?(pkg, req))
    # Above minimum version w/ package version
    req[:minimum_package_version] = '1.0'
    req[:maximum_package_version] = '2.0'
    assert(!Tpkg::package_meets_requirement?(pkg, req))

    FileUtils.rm_f(pkgfile)

    # More complicated test for: Can't upgrade if package has higher version
    # number but lower package version number
    pkgfile = make_package(:output_directory => @tempoutdir, :change => {'version' => '2.3', 'package_version' => '2' }, :remove => ['operatingsystem', 'architecture'])
    metadata = Tpkg::metadata_from_package(pkgfile)
    pkg = { :metadata => metadata, :source => pkgfile }
    req = { :name => 'testpkg' }
    # version number is not equal to min or max version. So we don't care if min/max package version satisfied or not
    req[:minimum_version] = '0.5'
    req[:maximum_version] = '3.0'
    req[:minimum_package_version] = '3'
    req[:maximum_package_version] = '3'
    assert(Tpkg::package_meets_requirement?(pkg, req))
    req[:minimum_package_version] = '1'
    req[:maximum_package_version] = '1'
    assert(Tpkg::package_meets_requirement?(pkg, req))
    # version is same as maximum_version, so we have to look at maximum_package_version
    req[:minimum_version] = '0.5'
    req[:maximum_version] = '2.3'
    req[:minimum_package_version] = '1'
    req[:maximum_package_version] = '1'
    assert(!Tpkg::package_meets_requirement?(pkg, req))
    req[:minimum_package_version] = '3'
    req[:maximum_package_version] = '3'
    assert(Tpkg::package_meets_requirement?(pkg, req))
    # version is same as minimum_version, so we have to look at minimum_package_version
    req[:minimum_version] = '2.3'
    req[:maximum_version] = '3.0'
    req[:minimum_package_version] = '3'
    req[:maximum_package_version] = '5'
    assert(!Tpkg::package_meets_requirement?(pkg, req))
    req[:minimum_package_version] = '2'
    req[:maximum_package_version] = '3'
    assert(Tpkg::package_meets_requirement?(pkg, req))

    FileUtils.rm_f(pkgfile)
    
    #
    # Test architecture and operatingsystem handling
    #
    
    req = { :name => 'testpkg' }
    
    # Package with no OS specified
    pkgfile = make_package(:output_directory => @tempoutdir, :remove => ['operatingsystem'], :change => {'architecture' => Facter['hardwaremodel'].value})
    metadata = Tpkg::metadata_from_package(pkgfile)
    pkg = { :metadata => metadata, :source => pkgfile }
    assert(Tpkg::package_meets_requirement?(pkg, req))
    FileUtils.rm_f(pkgfile)
    
    # Package with one matching OS
    pkgfile = make_package(:output_directory => @tempoutdir, :change => {'operatingsystem' => Tpkg::get_os, 'architecture' => Facter['hardwaremodel'].value})
    metadata = Tpkg::metadata_from_package(pkgfile)
    pkg = { :metadata => metadata, :source => pkgfile }
    assert(Tpkg::package_meets_requirement?(pkg, req))
    FileUtils.rm_f(pkgfile)
    
    # Package with a matching OS in a list of OSs
    pkgfile = make_package(:output_directory => @tempoutdir, :change => {'operatingsystem' => "RedHat,CentOS,#{Tpkg::get_os},FreeBSD,Solaris", 'architecture' => Facter['hardwaremodel'].value})
    metadata = Tpkg::metadata_from_package(pkgfile)
    pkg = { :metadata => metadata, :source => pkgfile }
    assert(Tpkg::package_meets_requirement?(pkg, req))
    FileUtils.rm_f(pkgfile)
    
    # Package with one non-matching OS
    pkgfile = make_package(:output_directory => @tempoutdir, :change => {'operatingsystem' => 'bogus_os', 'architecture' => Facter['hardwaremodel'].value})
    metadata = Tpkg::metadata_from_package(pkgfile)
    pkg = { :metadata => metadata, :source => pkgfile }
    assert(!Tpkg::package_meets_requirement?(pkg, req))
    FileUtils.rm_f(pkgfile)
    
    # Package with a list of non-matching OSs
    pkgfile = make_package(:output_directory => @tempoutdir, :change => {'operatingsystem' => 'bogus_os1,bogus_os2', 'architecture' => Facter['hardwaremodel'].value})
    metadata = Tpkg::metadata_from_package(pkgfile)
    pkg = { :metadata => metadata, :source => pkgfile }
    assert(!Tpkg::package_meets_requirement?(pkg, req))
    FileUtils.rm_f(pkgfile)
    
    # Package with no architecture specified
    pkgfile = make_package(:output_directory => @tempoutdir, :remove => ['architecture'], :change => {'operatingsystem' => Tpkg::get_os })
    metadata = Tpkg::metadata_from_package(pkgfile)
    pkg = { :metadata => metadata, :source => pkgfile }
    assert(Tpkg::package_meets_requirement?(pkg, req))
    FileUtils.rm_f(pkgfile)
    
    # Package with one matching architecture
    pkgfile = make_package(:output_directory => @tempoutdir, :change => {'operatingsystem' => Tpkg::get_os, 'architecture' => Facter['hardwaremodel'].value})
    metadata = Tpkg::metadata_from_package(pkgfile)
    pkg = { :metadata => metadata, :source => pkgfile }
    assert(Tpkg::package_meets_requirement?(pkg, req))
    FileUtils.rm_f(pkgfile)
    
    # Package with a matching architecture in a list of architectures
    pkgfile = make_package(:output_directory => @tempoutdir, :change => {'operatingsystem' => Tpkg::get_os, 'architecture' => "i386,x86_64,#{Facter['hardwaremodel'].value},sparc,powerpc"})
    metadata = Tpkg::metadata_from_package(pkgfile)
    pkg = { :metadata => metadata, :source => pkgfile }
    assert(Tpkg::package_meets_requirement?(pkg, req))
    FileUtils.rm_f(pkgfile)
    
    # Package with one non-matching architecture
    pkgfile = make_package(:output_directory => @tempoutdir, :change => {'operatingsystem' => Tpkg::get_os, 'architecture' => 'bogus_arch'})
    metadata = Tpkg::metadata_from_package(pkgfile)
    pkg = { :metadata => metadata, :source => pkgfile }
    assert(!Tpkg::package_meets_requirement?(pkg, req))
    FileUtils.rm_f(pkgfile)
    
    # Package with a list of non-matching architectures
    pkgfile = make_package(:output_directory => @tempoutdir, :change => {'operatingsystem' => Tpkg::get_os, 'architecture' => 'bogus_arch1,bogus_arch2'})
    metadata = Tpkg::metadata_from_package(pkgfile)
    pkg = { :metadata => metadata, :source => pkgfile }
    assert(!Tpkg::package_meets_requirement?(pkg, req))
    FileUtils.rm_f(pkgfile)

    # Package with operatingsystem and arch specified as regex
    pkgfile = make_package(:output_directory => @tempoutdir, :change => {'operatingsystem' => 'RedHat|CentOS|Fedora|Debian|Ubuntu|Solaris|FreeBSD|Darwin',  'architecture' => "i386|x86_64|#{Facter['hardwaremodel'].value}|sparc|powerpc"})
    metadata = Tpkg::metadata_from_package(pkgfile)
    pkg = { :metadata => metadata, :source => pkgfile }
    assert(Tpkg::package_meets_requirement?(pkg, req))
  end
  
  def test_available_packages_that_meet_requirement
    pkgfiles = []
    ['1.0', '1.1', '1.2', '1.3'].each do |ver|
      pkgfiles << make_package(:output_directory => @tempoutdir, :change => {'version' => ver}, :remove => ['operatingsystem', 'architecture'])
    end
    
    Dir.mktmpdir('testbase') do |testbase|
      tpkg = Tpkg.new(:base => testbase, :sources => pkgfiles)
      
      pkgs = tpkg.available_packages_that_meet_requirement
      nonnativepkgs = pkgs.select do |pkg|
        pkg[:source] != :native_installed && pkg[:source] != :native_available
      end
      assert_equal(4, nonnativepkgs.length)
      
      # Test that the caching logic stored the answer properly
      assert_equal(pkgs, tpkg.available_packages_cache[nil])
      # And test that it returns the cached value
      fakepkgs = pkgs.dup.pop
      tpkg.available_packages_cache[nil] = fakepkgs
      assert_equal(fakepkgs, tpkg.available_packages_that_meet_requirement)
      # Put things back to normal
      tpkg.available_packages_cache[nil] = pkgs
      
      req = { :name => 'testpkg' }
      
      req[:minimum_version] = '1.2'
      req[:maximum_version] = '2.0'
      pkgs = tpkg.available_packages_that_meet_requirement(req)
      assert_equal(2, pkgs.length)
      pkgs.each do |pkg|
        assert(pkg[:metadata][:version].to_f >= 1.2)
      end
      
      req[:minimum_version] = '1.1'
      req[:maximum_version] = '1.2'
      pkgs = tpkg.available_packages_that_meet_requirement(req)
      assert_equal(2, pkgs.length)
      pkgs.each do |pkg|
        assert(pkg[:metadata][:version].to_f >= 1.1)
        assert(pkg[:metadata][:version].to_f <= 1.2)
      end
      
      # Test a package name which has no available packages
      req[:name] = 'otherpkg'
      pkgs = tpkg.available_packages_that_meet_requirement(req)
      assert(pkgs.empty?)
      
      # Users should be able to specify a dependency such that they indicate
      # that the desired package has no package version.
      pkgfiles << make_package(:output_directory => @tempoutdir, :change => {'version' => '2'}, :remove => ['operatingsystem', 'architecture', 'package_version'])
      pkgfiles << make_package(:output_directory => @tempoutdir, :change => {'version' => '2', 'package_version' => '1'}, :remove => ['operatingsystem', 'architecture'])
      pkgfiles << make_package(:output_directory => @tempoutdir, :change => {'version' => '2', 'package_version' => '112'}, :remove => ['operatingsystem', 'architecture'])
      tpkg = Tpkg.new(:base => testbase, :sources => pkgfiles)
      
      req = { :name => 'testpkg' }
      
      # FIXME: These don't look like tests of
      # available_packages_that_meet_requirement.  I'm too lazy to find where
      # the wildcard support is implemented, but it isn't in
      # available_packages_that_meet_requirement.
      
      # Should only match package of version 2 and NO package version
      req[:allowed_versions] = '2'
      pkgs = tpkg.available_packages_that_meet_requirement(req)
      assert_equal(1, pkgs.length)
      
      # Should match any packages that has a version number that starts with 2
      req[:allowed_versions] = '2*'
      pkgs = tpkg.available_packages_that_meet_requirement(req)
      assert_equal(3, pkgs.length)
      
      # Should match any packages that is version 2 AND has a package version number
      req[:allowed_versions] = '2-*'
      pkgs = tpkg.available_packages_that_meet_requirement(req)
      assert_equal(2, pkgs.length)
      
      # Should match any packages that is version 2 AND has a package version number that ends with 2
      req[:allowed_versions] = '2-*2'
      pkgs = tpkg.available_packages_that_meet_requirement(req)
      assert_equal(1, pkgs.length)
    end
    
    pkgfiles.each { |pkgfile| FileUtils.rm_f(pkgfile) }
  end
  
  def test_best_solution
    # Test that best_solution gives us the right answer using our test
    # package set in a new, clean base
    Dir.mktmpdir('testbase') do |testbase|
      tpkg = Tpkg.new(:base => testbase, :sources => @pkgfiles)
      solution_packages = tpkg.best_solution([{:name => 'a', :type => :tpkg}], {}, ['a'])
      # We should end up with a-1.0, b-1.0 (the specific one, not the generic
      # one), c-1.2 and d-1.2
      assert_equal(4, solution_packages.length)
      good = ['a-1.0-1.tpkg', "b-1.0-1-#{Metadata.clean_for_filename(Tpkg.get_os)}.tpkg", 'c-1.2-1.tpkg', 'd-1.2-1.tpkg']
      solution_packages.each { |pkg| assert(good.any? { |g| pkg[:source].include?(g) }) }
    end
    
    # Now run a test to verify that we prefer already installed packages
    Dir.mktmpdir('testbase') do |testbase|
      #  First install an older version of a
      older_apkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'a', 'version' => '0.9' }, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      tpkg = Tpkg.new(:base => testbase, :sources => [older_apkg] + @pkgfiles)
      tpkg.install(['a=0.9'], PASSPHRASE)
      # Now request 'a' and verify that we get back the currently installed
      # 'a' pkg rather than the newer one that is available from our test
      # packages
      requirements = []
      packages = {}
      tpkg.requirements_for_currently_installed_packages(requirements, packages)
      requirements << {:name => 'a', :type => :tpkg}
      solution_packages = tpkg.best_solution(requirements, packages, ['a'])
      assert_equal(1, solution_packages.length)
      assert_equal(:currently_installed, solution_packages.first[:source])
      assert_equal('a', solution_packages.first[:metadata][:name])
      assert_equal('0.9', solution_packages.first[:metadata][:version])
      FileUtils.rm_f(older_apkg)
    end

    # Test that we don't prefer installed packages if :prefer is false
    Dir.mktmpdir('testbase') do |testbase|
      #  First install an older version of d
      older_dpkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'd', 'version' => '0.9' }, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      tpkg = Tpkg.new(:base => testbase, :sources => [older_dpkg] + @pkgfiles)
      tpkg.install(['d=0.9'], PASSPHRASE)
      # Now request an update of 'd' and verify that we get back the newer
      # available 'd' pkg rather than the currently installed package.
      requirements = []
      packages = {}
      tpkg.requirements_for_currently_installed_packages(requirements, packages)
      # Remove preference for currently installed package
      packages['d'].each do |pkg|
        if pkg[:source] == :currently_installed
          pkg[:prefer] = false
        end
      end
      solution_packages = tpkg.best_solution(requirements, packages, ['d'])
      assert_equal(1, solution_packages.length)
      assert(solution_packages.first[:source].include?('d-1.3-1.tpkg'))
      FileUtils.rm_f(older_dpkg)
    end

    # Test that we don't prefer installed packages if :prefer is false
    # This is a more complex test than the previous, as the 'a' package
    # in our test @pkgfiles has dependencies, whereas the initial older
    # version we install does not.  The new dependencies could throw off
    # the scoring process.
    Dir.mktmpdir('testbase') do |testbase|
      #  First install an older version of a
      older_apkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'a', 'version' => '0.9' }, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      tpkg = Tpkg.new(:base => testbase, :sources => [older_apkg] + @pkgfiles)
      tpkg.install(['a=0.9'], PASSPHRASE)
      # Now request an update of 'a' and verify that we get back the newer
      # available 'a' pkg rather than the currently installed package.
      requirements = []
      packages = {}
      tpkg.requirements_for_currently_installed_packages(requirements, packages)
      # Remove preference for currently installed package
      packages['a'].each do |pkg|
        if pkg[:source] == :currently_installed
          pkg[:prefer] = false
        end
      end
      solution_packages = tpkg.best_solution(requirements, packages, ['a'])
      # The solution should pull in the newer 'a' and its dependencies
      assert_equal(4, solution_packages.length)
      selectedapkg = solution_packages.find{|pkg| pkg[:metadata][:name] == 'a'}
      assert(selectedapkg[:source].include?('a-1.0-1.tpkg'))
      FileUtils.rm_f(older_apkg)
    end
    
    # Test that we can handle simultaneous dependency on a native package and
    # a tpkg with the same name. For this we need a native package that is
    # generally available on systems that developers are likely to use, I'm
    # going to use wget for now.
    nativedep = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'nativedep' }, :dependencies => {'wget' => {'native' => true}}, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
    tpkgdep = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'tpkgdep' }, :dependencies => {'wget' => {}}, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
    wget = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'wget' }, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
    parent = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'parent' }, :dependencies => {'nativedep' => {}, 'tpkgdep' => {}}, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
    Dir.mktmpdir('testbase') do |testbase|
      mixeddeppkgs = [nativedep, tpkgdep, wget, parent]
      tpkg = Tpkg.new(:base => testbase, :sources => mixeddeppkgs)
      solution_packages = tpkg.best_solution([{:name => 'parent', :type => :tpkg}], {}, ['parent'])
      # The solution should include the four tpkgs plus a native wget
      assert_equal(5, solution_packages.length)
      assert(solution_packages.any? {|sp| sp[:metadata][:name] == 'wget' && (sp[:source] == :native_available || sp[:source] == :native_installed)})
      assert(solution_packages.any? {|sp| sp[:metadata][:name] == 'wget' && sp[:source].include?('wget-1.0-1.tpkg')})
      mixeddeppkgs.each do |mdp|
        FileUtils.rm_f(mdp)
      end
    end
    
    # Test with no valid solution, ensure it fails
    Dir.mktmpdir('testbase') do |testbase|
      tpkg = Tpkg.new(:base => testbase, :sources => @pkgfiles)
      solution_packages = nil
      assert_nothing_raised { solution_packages = tpkg.best_solution([{:name => 'a', :type => :tpkg}, {:name => 'c', :minimum_version => '1.3', :type => :tpkg}], {}, ['a', 'c']) }
      assert_nil(solution_packages)
    end
    
    # The test recreates a set of circumstances that triggered a bug at one
    # point.  There are several versions of the requested package which depend
    # on a non-existent package.  This particular arrangement led to
    # attempting to reference a nil value as a pkg.
    Dir.mktmpdir('testbase') do |testbase|
      baddep1 = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'baddep', 'version' => '1' }, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      baddep2 = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'baddep', 'version' => '2' }, :dependencies => {'bogus' => {}}, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      baddep3 = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'baddep', 'version' => '2' }, :dependencies => {'bogus' => {}}, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      tpkg = Tpkg.new(:base => testbase, :sources => [baddep1, baddep2, baddep3])
      solution_packages = nil
      assert_nothing_raised { solution_packages = tpkg.best_solution([{:name => 'baddep', :type => :tpkg}], {}, ['baddep']) }
      assert_equal(1, solution_packages.length)
      assert(solution_packages.first[:source] == baddep1)
    end
    
    # This test recreates another set of circumstances that triggered a bug. 
    # The format of the packages argument to resolve_dependencies changed and
    # the attempts to dup it in order to avoid messing up the state of callers
    # of resolve_dependencies were no longer effective.  Thus the state of
    # callers of resolve_dependencies was messed up and it would fail to find
    # valid solutions.
    Dir.mktmpdir('testbase') do |testbase|
      baddep1 = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'baddep', 'version' => '1' }, :dependencies => {'notbogus' => {}}, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      baddep2 = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'baddep', 'version' => '2' }, :dependencies => {'notbogus' => {}, 'bogus' => {}}, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      notbogus = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'notbogus', 'version' => '1' }, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      bogus = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'bogus', 'version' => '1', 'operatingsystem' => 'bogusos' }, :remove => ['architecture', 'posix_acl', 'windows_acl'])
      tpkg = Tpkg.new(:base => testbase, :sources => [baddep1, baddep2, notbogus, bogus])
      solution_packages = nil
      assert_nothing_raised { solution_packages = tpkg.best_solution([{:name => 'baddep', :type => :tpkg}], {}, ['baddep']) }
      assert_equal(2, solution_packages.length)
      assert(solution_packages.any? {|sp| sp[:source] == baddep1})
      assert(solution_packages.any? {|sp| sp[:source] == notbogus})
    end
  end
  
  # best_solution is a thin wrapper of this method, most of the testing
  # is in test_best_solution
  def test_resolve_dependencies
    Dir.mktmpdir('testbase') do |testbase|
      tpkg = Tpkg.new(:base => testbase, :sources => @pkgfiles)
      
      result = tpkg.resolve_dependencies([{:name => 'a', :type => :tpkg}], {:tpkg => {}, :native => {}}, ['a'])
      assert(result.has_key?(:solution))
      solution = result[:solution]
      
      # We should end up with a-1.0, b-1.0 (the specific one, not the generic
      # one), c-1.2 and d-1.2
      assert_equal(4, solution.length)
      good = ['a-1.0-1.tpkg', "b-1.0-1-#{Metadata.clean_for_filename(Tpkg.get_os)}.tpkg", 'c-1.2-1.tpkg', 'd-1.2-1.tpkg']
      solution.each { |pkg| assert(good.any? { |g| pkg[:source].include?(g) }) }
    end
  end
  
  # This method is only used by resolve_dependencies, so the testing
  # here is minimal.
  def test_check_solution
    Dir.mktmpdir('testbase') do |testbase|
      tpkg = Tpkg.new(:base => testbase, :sources => @pkgfiles)
      
      solution = nil
      requirements = [{:name => 'c', :minimum_version => '1.3', :type => :tpkg}, {:name => 'd', :minimum_version => '1.3', :type => :tpkg}]
      packages = {:tpkg => {}, :native => {}}
      requirements.each do |req|
        packages[req[:type]][req[:name]] = tpkg.available_packages_that_meet_requirement(req)
      end
      core_packages = ['c']
      number_of_possible_solutions_checked = 0
      
      result = nil
      # Check a valid solution
      solution = {:pkgs => packages[:tpkg].values.flatten}
      assert_nothing_raised { result = tpkg.check_solution(solution, requirements, packages, core_packages, number_of_possible_solutions_checked) }
      assert(result.has_key?(:solution))
      assert_equal(packages[:tpkg].values.flatten, result[:solution])
      
      # Check an invalid solution
      xpkgfile = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'x' }, :dependencies => {'y' => {}}, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      metadata = Tpkg::metadata_from_package(xpkgfile)
      xpkg = {:metadata => metadata}
      solution[:pkgs] << xpkg
      assert_nothing_raised { result = tpkg.check_solution(solution, requirements, packages, core_packages, number_of_possible_solutions_checked) }
      assert(!result.has_key?(:solution))
      assert(result.has_key?(:number_of_possible_solutions_checked))
      assert(result[:number_of_possible_solutions_checked] > 0)
      FileUtils.rm_f(xpkgfile)
    end
  end
  
  def test_requirements_for_currently_installed_package
    pkgfile = make_package(:output_directory => @tempoutdir, :remove => ['operatingsystem', 'architecture'])
    pkgfile2 = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'testpkg2' }, :remove => ['package_version', 'operatingsystem', 'architecture'])
    Dir.mktmpdir('testbase') do |testbase|
      tpkg = Tpkg.new(:base => testbase, :sources => [pkgfile, pkgfile2])
      tpkg.install(['testpkg'])
      tpkg.install(['testpkg2'])
      requirements = nil
      assert_nothing_raised { requirements = tpkg.requirements_for_currently_installed_package('testpkg') }
      assert_equal(1, requirements.length)
      assert_equal('testpkg', requirements.first[:name])
      assert_equal('1.0', requirements.first[:minimum_version])
      assert_equal('1', requirements.first[:minimum_package_version])
      assert_equal(:tpkg, requirements.first[:type])
      assert_nothing_raised { requirements = tpkg.requirements_for_currently_installed_package('testpkg2') }
      assert_equal(1, requirements.length)
      assert_equal('testpkg2', requirements.first[:name])
      assert_equal('1.0', requirements.first[:minimum_version])
      assert_nil(requirements.first[:minimum_package_version])
      assert_equal(:tpkg, requirements.first[:type])
    end
    FileUtils.rm_f(pkgfile)
    FileUtils.rm_f(pkgfile2)
  end

  def test_requirements_for_currently_installed_packages
    Dir.mktmpdir('testbase') do |testbase|
      apkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'a', 'version' => '2.0' }, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      tpkg = Tpkg.new(:base => testbase, :sources => [apkg])
      tpkg.install(['a'], PASSPHRASE)
      requirements = []
      packages = {}
      tpkg.requirements_for_currently_installed_packages(requirements, packages)
      assert_equal(1, requirements.length)
      assert_equal('a', requirements.first[:name])
      assert_equal('2.0', requirements.first[:minimum_version])
      assert_equal(:tpkg, requirements.first[:type])
      # Given the way we set up the tpkg instance we should have two entries
      # in packages, one for the installed copy of the package and one for the
      # uninstalled copy
      assert_equal(2, packages['a'].length)
      assert(packages['a'].any? { |pkg| pkg[:source] == :currently_installed })
      assert(packages['a'].any? { |pkg| pkg[:source].include?('a-2.0-1.tpkg') })
      currently_installed_pkg = packages['a'].find { |pkg| pkg[:source] == :currently_installed }
      assert(currently_installed_pkg[:prefer])
      FileUtils.rm_f(apkg)
    end
  end
  def test_parse_request
    req = Tpkg::parse_request('a')
    assert_equal(2, req.length)
    assert_equal('a', req[:name])
    assert_equal(:tpkg, req[:type])
    
    req = Tpkg::parse_request('a=1.0')
    assert_equal(4, req.length)
    assert_equal('a', req[:name])
    assert_equal('1.0', req[:minimum_version])
    assert_equal('1.0', req[:maximum_version])
    assert_equal(:tpkg, req[:type])
    
    req = Tpkg::parse_request('a=1.0=1')
    assert_equal(6, req.length)
    assert_equal('a', req[:name])
    assert_equal('1.0', req[:minimum_version])
    assert_equal('1.0', req[:maximum_version])
    assert_equal('1', req[:minimum_package_version])
    assert_equal('1', req[:maximum_package_version])
    assert_equal(:tpkg, req[:type])
  end
  def test_parse_requests
    Dir.mktmpdir('testbase') do |testbase|
      tpkg = Tpkg.new(:base => testbase, :sources => @pkgfiles)
      requirements = []
      packages = {}
      
      # Test various package spec requests
      tpkg.parse_requests(['a'], requirements, packages)
      assert_equal(1, requirements.length)
      assert_equal(2, requirements.first.length)
      assert_equal('a', requirements.first[:name])
      assert_equal(:tpkg, requirements.first[:type])
      assert_equal(1, packages['a'].length)
      requirements.clear
      packages.clear
      
      tpkg.parse_requests(['a=1.0'], requirements, packages)
      assert_equal(1, requirements.length)
      assert_equal(4, requirements.first.length)
      assert_equal('a', requirements.first[:name])
      assert_equal('1.0', requirements.first[:minimum_version])
      assert_equal('1.0', requirements.first[:maximum_version])
      assert_equal(:tpkg, requirements.first[:type])
      assert_equal(1, packages['a'].length)
      requirements.clear
      packages.clear
      
      tpkg.parse_requests(['a=1.0=1'], requirements, packages)
      assert_equal(1, requirements.length)
      assert_equal(6, requirements.first.length)
      assert_equal('a', requirements.first[:name])
      assert_equal('1.0', requirements.first[:minimum_version])
      assert_equal('1.0', requirements.first[:maximum_version])
      assert_equal('1', requirements.first[:minimum_package_version])
      assert_equal('1', requirements.first[:maximum_package_version])
      assert_equal(:tpkg, requirements.first[:type])
      assert_equal(1, packages['a'].length)
      requirements.clear
      packages.clear
      
      # Test with a given filename (full path to the actual package)  rather than a package spec
      apkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'a', 'version' => '2.0' }, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      tpkg.parse_requests([apkg], requirements, packages)
      assert_equal(1, requirements.length)
      assert_equal(2, requirements.first.length)   # should this be 6?
      assert_equal('a', requirements.first[:name])
      assert_equal(:tpkg, requirements.first[:type])
      assert_equal(1, packages['a'].length)
      requirements.clear
      packages.clear
      FileUtils.rm_f(apkg)
      
      # Test with a filename of a package that has been installed rather than a package spec
      apkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'a', 'version' => '2.0' }, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      tpkg.install([apkg], PASSPHRASE)
      FileUtils.rm_f(apkg)
      tpkg.parse_requests([File.basename(apkg)], requirements, packages)
      assert_equal(1, requirements.length)
      assert_equal(3, requirements.first.length)  # name, filename, type
      assert_equal('a', requirements.first[:name])
      assert_equal(File.basename(apkg), requirements.first[:filename])
      assert_equal(:tpkg, requirements.first[:type])
      assert_equal(1, packages['a'].length)
      requirements.clear
      packages.clear
      
      # Test package with special character like "++"
      apkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'a++', 'version' => '2.0' }, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      tpkg = Tpkg.new(:base => testbase, :sources => (@pkgfiles << apkg))
      tpkg.parse_requests([apkg], requirements, packages)
      assert_equal(1, requirements.length)
      assert_equal(2, requirements.first.length)  
      assert_equal('a++', requirements.first[:name])
      assert_equal(:tpkg, requirements.first[:type])
      assert_equal(1, packages['a++'].length)
      
      requirements.clear
      packages.clear
      
      tpkg.parse_requests(["a++"], requirements, packages)
      assert_equal(1, requirements.length)
      assert_equal(2, requirements.first.length)  
      assert_equal('a++', requirements.first[:name])
      assert_equal(:tpkg, requirements.first[:type])
      assert_equal(1, packages['a++'].length)
    end
  end
  
  def test_check_requests
    # check_requests does some additional checks for requests by
    # filename or URI, test those
    Dir.mktmpdir('testbase') do |testbase|
      tpkg = Tpkg.new(:base => testbase, :sources => @pkgfiles)
      requirements = []
      packages = {}
      
      # First just check that it properly checks a package with dependencies
      apkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'a', 'version' => '2.0' }, :dependencies => {'b' => {}}, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      tpkg.parse_requests([apkg], requirements, packages)
      assert_nothing_raised { tpkg.check_requests(packages) }
      assert_equal(1, requirements.length)
      assert_equal(2, requirements.first.length)
      assert_equal('a', requirements.first[:name])
      assert_equal(:tpkg, requirements.first[:type])
      assert_equal(1, packages['a'].length)
      requirements.clear
      packages.clear
      FileUtils.rm_f(apkg)
      
      # package dependencies on install when installing local package files
      # (i.e. not sourced from a server)
      # Check that tpkg accept list of local packages where one depends on another
      localapkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'locala', 'version' => '1.0' }, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      localbpkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'localb', 'version' => '1.0' }, :dependencies => {'locala' => {}}, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      localcpkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'localc', 'version' => '1.0' }, :dependencies => {'nonexisting' => {}}, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      tpkg.parse_requests([localapkg, localbpkg], requirements, packages) 
      assert_nothing_raised { tpkg.check_requests(packages) }
      requirements.clear
      packages.clear
      tpkg.parse_requests([localbpkg, localapkg], requirements, packages) 
      assert_nothing_raised { tpkg.check_requests(packages) }
      requirements.clear
      packages.clear
      # Should not be ok since localc depends on nonexisting package
      tpkg.parse_requests([localapkg, localbpkg, localcpkg], requirements, packages) 
      assert_raise(RuntimeError) { tpkg.check_requests(packages) }
      requirements.clear
      packages.clear
      FileUtils.rm_f(localapkg)
      FileUtils.rm_f(localbpkg)
      
      # Verify that it rejects a package that can't be installed on this
      # machine
      apkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'a', 'version' => '2.0', 'operatingsystem' => 'bogusos' }, :dependencies => {'b' => {}}, :remove => ['posix_acl', 'windows_acl'])
      tpkg.parse_requests([apkg], requirements, packages) 
      assert_raise(RuntimeError) { tpkg.check_requests(packages) }
      requirements.clear
      packages.clear
      FileUtils.rm_f(apkg)    
      
      # Verify that it rejects a package with an unresolvable dependency
      apkg = make_package(:output_directory => @tempoutdir, :change => { 'name' => 'a', 'version' => '2.0' }, :dependencies => {'x' => {}}, :remove => ['operatingsystem', 'architecture', 'posix_acl', 'windows_acl'])
      tpkg.parse_requests([apkg], requirements, packages) 
      assert_raise(RuntimeError) { tpkg.check_requests(packages) }
      requirements.clear
      packages.clear
      FileUtils.rm_f(apkg)    
    end
  end
  
  def teardown
    @pkgfiles.each { |pkgfile| FileUtils.rm_f(pkgfile) }
    FileUtils.rm_rf(@tempoutdir)
  end
end
