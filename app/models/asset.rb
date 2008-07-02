include DirectoryArray

class Asset
  attr_reader :parent_id, :version, :pathname, :id
  attr_accessor :errors, :success

  def initialize(full_path, id, version)
    @pathname = Pathname.new(full_path) unless full_path.nil?
    @id = id
    @version = version
    @errors = Errors.new
    @success = false
  end

  def self.find(id, version)
    if confirm_lock(version)
      asset_path = id2path(id)
      Asset.new(asset_path, id, version)
    else
      empty_asset = Asset.new(nil, id, version)
      empty_asset.errors.no = 0
      empty_asset
    end    
  end

  def update(asset)
    asset_name = Asset.confirm_asset_validity_and_sanitize(asset['name'])
    version = asset['version']
    if asset_name
        if Asset.confirm_lock(version) 
          new_asset = Pathname.new(File.join(@pathname.parent, asset_name))
          if @pathname.directory?
            unless new_asset.directory?
              @pathname.rename(new_asset)
              @success = "Directory has been sucessfully edited."
              AssetLock.new_lock_version
            else
              @errors.no = 1
            end
          elsif @pathname.file?
            unless new_asset.file?
              @pathname.rename(new_asset)
              @success = "Filename has been sucessfully edited."
              AssetLock.new_lock_version
            else
              @errors.no = 1
            end
          end
        else
          @errors.no = 0 
        end
    else
      @errors.no = 2 
    end
    @success
  end

  def destroy
    if Asset.confirm_lock(@version) and (!@id.nil? and @id.to_s.strip != '')
      path = id2path(@id)
      return false if (path.to_s == Asset.get_absolute_path or path.to_s.index(Asset.get_absolute_path) != 0) #just in case
      if path.directory?
        FileUtils.rm_r path, :force => true
      elsif path.file?
        path.delete
      end
      @success = true
      AssetLock.new_lock_version         
    end
    @success
  end

  protected

  def self.get_absolute_path
    FileBrowserExtension.asset_path
  end

  def self.get_upload_location(parent_id)
    if parent_id == '' or parent_id.nil?
      upload_location = self.get_absolute_path        
    else
      upload_location = id2path(parent_id)        
    end
    return upload_location
  end

  def self.confirm_lock(version)
    return false if (version.nil? or version.to_s.strip == '')
    current_version = AssetLock.lock_version
    if version.to_s == current_version.to_s
      return true
    else
      return false
    end
  end

  def self.confirm_asset_validity_and_sanitize(asset)
    asset_absolute_path = self.get_absolute_path
    full_path = File.join(asset_absolute_path, asset)
    expand_full_path = File.expand_path(full_path)
    if (asset.slice(0,1) == '.') 
      return false
    elsif asset.match(/\/|\\/) 
      return false
    elsif expand_full_path.index(asset_absolute_path) != 0
      return false
    else
      asset.gsub! /[^\w\.\-]/, '_'
      return asset
    end
  end

  class Errors
     attr_accessor :no, :count, :full_messages

     def initialize
        @no = nil
        @full_messages = []
        @count = 0
     end

     def no=(error_no)
        @no = error_no
        @full_messages << CLIENT_ERRORS[@no]
        @count = @count + 1
     end

     CLIENT_ERRORS = [
       "The assets have been modified since it was last loaded hence the requested action could not be performed.",
       "The Asset name you are trying to create/edit already exists hence the requested action could not be performed.",
       "Asset name should not contain / \\ or a leading period.",
     ]
  end

end
