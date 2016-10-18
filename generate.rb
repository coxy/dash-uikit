require 'nokogiri'
require 'sqlite3'
require 'json'

# Remove existing docs (if any), download latest version and move into docset
%x{
  rm -rf UIKit.docset/Contents/Resources
  mkdir UIKit.docset/Contents/Resources
  wget https://github.com/uikit/uikit/archive/master.zip -O uikit-master.zip
  unzip uikit-master.zip
  mkdir UIKit.docset/Contents/Resources/Documents
  mv uikit-master/* UIKit.docset/Contents/Resources/Documents/
  rm -rf uikit-master
  rm uikit-master.zip
}

resources_path = 'UIKit.docset/Contents/Resources'
documents_path = "#{resources_path}/Documents"

# init sqlite3 db
db = SQLite3::Database.new("#{resources_path}/docSet.dsidx")
db.execute('CREATE TABLE IF NOT EXISTS searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);')
db.execute('CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path);')

# Guides
guides = %w{
  documentation_get-started.html
  documentation_how-to-customize.html
  documentation_layouts.html
  documentation_project-structure.html
  documentation_less-sass.html
  documentation_create-a-theme.html
  documentation_create-a-style.html
  documentation_customizer-json.html
  documentation_javascript.html
  components.html
  addons.html
}

# Don't index these
ignore = %w{
  index.html
  layouts_blog.html
  layouts_contact.html
  layouts_documentation.html
  layouts_frontpage.html
  layouts_login.html
  layouts_portfolio.html
  layouts_post.html
  customizer.html
}

docs = Dir["#{documents_path}/*.html"] + Dir["#{documents_path}/docs/*.html"]
docs.each do |doc|
  
  # Cleanup
  file = File.read(doc)
  file.gsub!('<li><a href="customizer.html">Customizer</a></li>',"")
  file.gsub!('<li><a href="docs/customizer.html">Customizer</a></li>',"")
  file.gsub!('<li><a href="../showcase/index.html">Showcase</a></li>',"")
  file.gsub!('<li><a href="showcase/index.html">Showcase</a></li>',"")
  file.gsub!(' - UIkit documentation</title>',"</title>")
  File.open(doc,'w'){|f|f<<file}

  filename = File.basename(doc)
  
  # don't index this file if in ignore list
  unless ignore.include?(filename)

    nok = Nokogiri::HTML(file)
    index_title = nok.css("h1").first.text
    index_path = doc.gsub("#{documents_path}/","")
    
    if filename =~ /addons_/
      index_title = "#{index_title} (Add-on)"
    end
   
    if guides.include?(filename)
      # index this file as a Guide
      index_type = 'Guide'
    else
      # index this file as a Component
      index_type = 'Component'
    end
    # insert this file into the index
    db.execute "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('#{index_title}', '#{index_type}', '#{index_path}');"
  end
end

# tar it up
%x{tar --exclude='.DS_Store' -cvzf UIKit.tgz UIKit.docset}

# display version number
puts "Done. Use this version in the docset.json file:"
puts JSON.parse(File.read("#{documents_path}/package.json"))["version"]
