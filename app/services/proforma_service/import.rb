# frozen_string_literal: true

module ProformaService
  class Import < ServiceBase
    def initialize(zip:, user:)
      @zip = zip
      @user = user
    end

    def execute
      if single_task?
        importer = Proforma::Importer.new(@zip)
        @task = importer.perform
        exercise = ConvertTaskToExercise.call(task: @task, user: @user, exercise: base_exercise)
        ActiveRecord::Base.transaction do
          exercise.save_old_version if exercise.persisted?
          exercise.save!
        end

        exercise
      else
        import_multi
      end
    end

    private

    def base_exercise
      exercise = Exercise.unscoped.find_by(uuid: @task.uuid)
      if exercise
        return exercise if exercise.updatable_by?(@user)

        return Exercise.new(uuid: SecureRandom.uuid)
      end

      Exercise.new(uuid: @task.uuid || SecureRandom.uuid)
    end

    def import_multi
      Zip::File.open(@zip.path) do |zip_file|
        zip_files = zip_file.filter { |entry| entry.name.match?(/\.zip$/) }
        begin
          zip_files.map! do |entry|
            store_zip_entry_in_tempfile entry
          end
          zip_files.map do |proforma_file|
            Import.call(zip: proforma_file, user: @user)
          end
        ensure
          zip_files.each(&:unlink)
        end
      end
    end

    def store_zip_entry_in_tempfile(entry)
      tempfile = Tempfile.new(entry.name)
      tempfile.write entry.get_input_stream.read.force_encoding('UTF-8')
      tempfile.rewind
      tempfile
    end

    def single_task?
      filenames = Zip::File.open(@zip.path) do |zip_file|
        zip_file.map(&:name)
      end

      filenames.select { |f| f[/\.xml$/] }.any?
    rescue Zip::Error
      raise Proforma::InvalidZip
    end
  end
end
