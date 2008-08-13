class FileAsset < Asset
  attr_reader :uploaded_data

  def initialize(asset)
    @uploaded_data = asset['uploaded_data']
    filename = @uploaded_data.blank? ? '' : @uploaded_data.original_filename
    filename = asset['name'] if asset['name']
    @asset_name = sanitize(filename)
    @version = asset['version']
    if full_pathname(@asset_name).expand_path == Pathname.new(absolute_path).expand_path
      @parent = ""
    else
      @parent = asset['parent']
    end
  end

  def save
    if valid?
      begin
        raise Errors, :modified unless AssetLock.confirm_lock(@version)
        File.open(full_pathname(rel_path), 'wb') { |f| f.write(@uploaded_data.read) }
        @version = AssetLock.new_lock_version
      rescue Errors => e
        add_error(e)
      end
    end
  end

  def destroy
      path = full_pathname(rel_path)
      raise Errors, :illegal_path if (path.to_s == absolute_path or path.to_s.index(absolute_path) != 0) 
      raise Errors, :modified unless Asset.find(rel_path, @version).exists? 
      path.delete
      AssetLock.new_lock_version         
      return true
    rescue Errors => e 
      add_error(e)
      return false
  end

  def extension 
    ext = pathname.extname
    ext.slice(1, ext.length) if ext.slice(0,1) == '.'
  end

  def image?
    ext = extension.downcase unless extension.nil?
    return true if %w[png jpg jpeg bmp gif].include?(ext)
    return false 
  end  

  def embed_tag   
    asset_path = pathname
    if image?
      file_content = pathname.read
      img = ImageSize.new(file_content, extension)    
      return "<img src='/#{rel_path}' width='#{img.get_width}px' height='#{img.get_height}px' />"
    else
      return "<a href='/#{rel_path}'>#{@asset_name.capitalize}</a>"
    end
  end

  def description    
    image? ? "Image" : "File"
  end

  def html_class
    "no-children"
  end

  def icon
    "admin/page.png"    
  end

end
