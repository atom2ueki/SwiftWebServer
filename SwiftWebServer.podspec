Pod::Spec.new do |spec|
spec.name         = "SwiftWebServer"
spec.version      = "0.0.1"
spec.summary      = "A short description of SwiftWebServer."

spec.description      = "A detail description of SwiftWebServer."
spec.homepage         = "https://github.com/atom2ueki/SwiftWebServer"
spec.license          = { :type => "MIT", :txt => "FILE_LICENSE" }

spec.author           = { "Tony Li" => "atom2ueki@gmail.com" }
spec.platform         = :ios, "10.0" # add macos later if support.
spec.swift_version    = '5.1'

spec.source       = { :git => "https://github.com/atom2ueki/SwiftWebServer.git", :tag => "#{spec.version}" }

spec.framework = 'CoreFoundation', 'Foundation'

spec.source_files = 'SwiftWebServer/**/*.swift'
spec.resources = 'SwiftWebServer/**/*.{js,css,png,jpeg,jpg,pdf,bundle,storyboard,xib,xcassets,strings}'

end
