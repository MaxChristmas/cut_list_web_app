class AddProjectToPdfExports < ActiveRecord::Migration[8.1]
  def change
    add_reference :pdf_exports, :project, foreign_key: true
  end
end
