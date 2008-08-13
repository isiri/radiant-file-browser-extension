class DirectoryAsset < Asset

  def initialize(asset)
    @version = asset['version']
    @asset_name = sanitize(asset['name'])
    if full_pathname(@asset_name).expand_path == Pathname.new(absolute_path).expand_path
      @parent = ""
    else
      @parent = asset['parent']
    end
  end

  def save
    if valid?      
      begin   
        new_dir = full_pathname(rel_path)
        raise Errors, :modified unless AssetLock.confirm_lock(@version)
        Dir.mkdir(new_dir)       
        @version = AssetLock.new_lock_version
      rescue Errors => e
        add_error(e)
      end
    end
    @id
  end
  
  def size
    # Don't report size for directories, it would return bogus size info (the 'directory file' on disk)
  end

  def destroy
      path = full_pathname(rel_path)
      raise Errors, :illegal_path if (path.to_s == absolute_path or path.to_s.index(absolute_path) != 0) 
      raise Errors, :modified unless Asset.find(rel_path, @version).exists? 
      FileUtils.rm_r path, :force => true
      AssetLock.new_lock_version         
      return true
    rescue Errors => e 
      add_error(e)
      return false
  end

  def description
    "Folder" 
  end

  def children
    pathname.children.map { |c| (Asset.find_by_pathname(c) unless c.basename.to_s =~ (/^\./) ) }.compact
  end

  def html_class
    self.children.empty? ? "no-children" : "children-hidden" 
  end

  def root?
    pathname.expand_path == Pathname.new(absolute_path).expand_path
  end

  def icon
    "admin/directory.gif"
  end

end
