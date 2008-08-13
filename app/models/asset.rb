include DirectoryArray

class Asset
  include Validatable
  attr_reader :version, :asset_name, :parent

  validates_each :asset_name, :logic => lambda {
    expanded_full_path = full_pathname((File.join(@parent, @asset_name))).expand_path 
    class_type = self.class.to_s.gsub(/Asset/,'').downcase
    if @asset_name.blank?
      errors.add(:asset_name, Errors::CLIENT_ERRORS[:blankname])
    elsif (@asset_name.slice(0,1) == '.') || @asset_name.match(/\/|\\/)
      errors.add(:asset_name, Errors::CLIENT_ERRORS[:illegal_name])
    elsif expanded_full_path.to_s.index(absolute_path) != 0
      errors.add(:asset_name, Errors::CLIENT_ERRORS[:illegal_path])
    elsif Pathname.new(expanded_full_path).send("#{class_type}?") 
      errors.add(:asset_name, Errors::CLIENT_ERRORS[:exists])    
    end
  }

  def rename(asset)
    rename_asset_path = rel_path
    @asset_name = sanitize(asset['name'])
    begin
      raise Errors, :unknown unless self.exists?
      if valid?
        raise Errors, :modified unless Asset.find(rename_asset_path, @version).exists? 
        asset_pathname = full_pathname(rename_asset_path) 
        new_asset = Pathname.new(File.join(asset_pathname.parent, @asset_name))
        asset_pathname.rename(new_asset)
        @version = AssetLock.new_lock_version
        @parent = asset_pathname.parent
        return true
      end
    rescue Errors => e
        add_error(e)
        return false     
    end
  end
  
  def size
    pathname.size
  end  

  def exists?
    pathname.nil? ? false : true
  end

  def lock
    # TODO: Abstract away all lock versiony stuff.
    # asset.version should probably be the only public interface
    AssetLock.lock_version
  end

  def pathname
    full_pathname(rel_path)
  end

  def basename
    pathname.basename
  end

  def rel_path
    full_pathname(File.join(@parent, @asset_name)).expand_path.relative_path_from(Pathname.new(absolute_path)).to_s
  end

  class << self

    def find(*args)
      case args.first
        when :root then root
        else find_from_id(args[0], args[1])
      end
    end
    
    def root
      find_by_pathname(Pathname.new(absolute_path))
    end

    def find_from_id(path, version)
      if AssetLock.confirm_lock(version) and !path.blank? 
        full_path = full_pathname(path)
        find_by_pathname(full_path, version)
      else     
        empty_asset = DirectoryAsset.new('name' => '', 'pathname' => nil, 'new_type' => '')
        id.blank? ? err_type = :blankid : err_type = :modified
        empty_asset.errors.add(:base, Errors::CLIENT_ERRORS[err_type])      
        empty_asset       
      end    
    end

    def find_by_pathname(asset_path, version=AssetLock.lock_version)
      name = asset_path.basename.to_s
      asset_absolute_path = Pathname.new(absolute_path)
      asset = asset_path.relative_path_from(asset_absolute_path)
      raise Errors, :illegal_name if name =~ (/^\./) 
      raise Errors, :illegal_path if asset_path.to_s.index(absolute_path) != 0 
      if asset_path.directory?
        DirectoryAsset.new('name' => asset.basename.to_s, 'parent' => asset.parent.to_s, 'version' => version)
      else
        FileAsset.new('name' => asset.basename.to_s, 'parent' => asset.parent.to_s, 'version' => version)
      end 
    end

    def full_pathname(relative_path)
      Pathname.new(File.join(absolute_path, relative_path)).expand_path
    end

  end

  protected

  def absolute_path
    FileBrowserExtension.asset_path
  end

  def full_pathname(relative_path)
    Asset.full_pathname(relative_path)
  end

  def add_error(e)
    case e.message
      when :exists
        errors.add(:asset_name, Errors::CLIENT_ERRORS[e.message])
      when :modified
        errors.add(:base, Errors::CLIENT_ERRORS[e.message])
      when :illegal_path
        errors.add(:asset_name, Errors::CLIENT_ERRORS[e.message])
      when :illegal_name
        errors.add(:asset_name, Errors::CLIENT_ERRORS[e.message])
      else
        errors.add(:base, Errors::CLIENT_ERRORS[:unknown])
    end
  end

  def sanitize(asset_name)
    asset_name.gsub! /[^\w\.\-]/, '_'
    asset_name
  end

  class Errors < StandardError

    CLIENT_ERRORS = {
       :modified => "The Assets have been changed since it was last loaded hence the requested action could not be performed.",
       :exists => "already exists.",
       :illegal_name => "contains illegal characters.",
       :illegal_path => "must not escape from the assets directory.",
       :unknown => "An unknown error occured.",
       :blankid => "An error occured due to id field being blank.",
       :blankname => "field cannot be blank",
    }

  end

end
