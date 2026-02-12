class RenameSheetDimensionsInProjects < ActiveRecord::Migration[8.1]
  def change
    rename_column :projects, :sheet_width, :sheet_length
    rename_column :projects, :sheet_height, :sheet_width
  end
end
