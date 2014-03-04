#!ruby

require 'pairtree'
require 'zip'
require 'fileutils'
require "rexml/document"
require "digest/md5"
require "pry"

######## UNZIP ############

namespace = 'uc1'
id = ARGV[0]
puts "extracting zip #{id}"
dollarify_home = "/ram/dollarify"
if not File.directory? dollarify_home
    Dir.mkdir(dollarify_home)
end

if not File.directory? "#{dollarify_home}/#{id}"
    Dir.mkdir("#{dollarify_home}/#{id}")
end

Dir.chdir(dollarify_home)

pairtree = Pairtree.at("/sdr1/obj/#{namespace}",:prefix=>"#{namespace}.",:create => false)
obj = pairtree["#{namespace}.#{id}"]


Zip::File.open(obj.open("#{id}.zip").path) do |zip|

    zip.entries.each do |entry|
        zip.extract(entry,entry.name)
    end

end


####### DOLLARIFY ##########

Dir.chdir(id)

namespaces = {"mets"=>"http://www.loc.gov/METS/",
    "xlink"=>"http://www.w3.org/1999/xlink",
    "marc"=>"http://www.loc.gov/MARC21/slim",
    "gbs"=>"http://books.google.com/gbs",
    "premis"=>"info:lc/xmlns/premis-v2"}

newid = '$' + id
Dir.entries(".").keep_if { |d| d !~ /^\./ }.each() do |file|
    File.rename(file,file.sub('_B','_$B'))
end


# fix image DocumentName & dc:source
puts "Fixing images #{id}"
docnameprefix = "UCAL_#{newid.upcase()}".sub('$','$$')
system("exiftool -overwrite_original '-IFD0:DocumentName<#{docnameprefix}/$filename' '-XMP-dc:source<#{docnameprefix}/$filename' *.tif")
system("exiftool -overwrite_original '-XMP-dc:source<#{docnameprefix}/$filename' *.jp2")

# fix mets
puts "Fixing mets #{id}"
file = File.new("UCAL_#{newid.upcase()}.xml")
doc = REXML::Document.new file


# - OBJID
REXML::XPath.each(doc,"//mets:mets",namespaces) do |mets|
    mets.add_attribute('OBJID',mets.attribute('OBJID').value.sub('_B','_$B'))
end

# - 955$b
REXML::XPath.each(doc,'//marc:datafield[@tag="955"]/marc:subfield[@code="b"]',namespaces) do |subfield_955b| 
    subfield_955b.text = subfield_955b.text.prepend('$')
end

# - gbs:sourceIdentifier
REXML::XPath.each(doc,'//gbs:sourceIdentifier',namespaces) do |source_identifier| 
    source_identifier.text = source_identifier.text.prepend('$')
end

# - premis:objectIdentifierValue
REXML::XPath.each(doc,"//premis:objectIdentifierValue",namespaces) do | objid |
    objid.text = objid.text.sub('_B','_$B')
end

# - Update checksums, fix mets:FLocat@xlink:href
REXML::XPath.each(doc,'//mets:file',namespaces) do |file|
    flocat = REXML::XPath.first(file,'mets:FLocat',namespaces)
    flocat.add_attribute('xlink:href',flocat.attribute('xlink:href').value.sub('_B','_$B'))
    filename = flocat.attribute('xlink:href').value
    md5sum = Digest::MD5.file(filename).hexdigest
    file.add_attribute('CHECKSUM',md5sum)
end

file.close()

formatter = REXML::Formatters::Default.new()
formatter.write(doc,File.new("UCAL_#{newid.upcase()}.xml",mode="w"))

######### REZIP ###########
puts "rezipping: #{id}"

Zip::File.open("#{dollarify_home}/#{newid}.zip", Zip::File::CREATE) do |zip|
    Dir.entries("#{dollarify_home}/#{id}").each do |file|
      zip.add(file, "#{dollarify_home}/#{id}/#{file}")
    end
end

puts "cleaning up: #{id}"
FileUtils::rm_rf("/ram/dollarify/#{id}")
