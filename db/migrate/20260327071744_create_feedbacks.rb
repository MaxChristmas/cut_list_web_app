class CreateFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :feedbacks do |t|
      t.integer :rating
      t.text :improvement
      t.text :feature_request
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
