Pod::Spec.new do |s|

    s.name         = "SwiftLocation"
    s.platform     = :ios, "9.0"
    s.version      = "1.0"
    s.summary      = "Universal location manager with automatic authorization handling."
    s.homepage     = "https://github.com/jsahoo/SwiftLocation"
    s.license      = { :type => "MIT", :file => "LICENSE" }
    s.author       = "Jonathan Sahoo"
    s.source       = { :git => "https://github.com/jsahoo/SwiftLocation.git", :tag => s.version }
    s.source_files  = "SwiftLocation/SwiftLocation.swift"
    s.requires_arc = true

end