# frozen_string_literal: true

module ProformaService
  class Import < ServiceBase
    def initialize(zip: nil, user: nil)
      @zip = zip
      @user = user
    end

    def execute
      if single_task?
        importer = Proforma::Importer.new(@zip)
        @task = importer.perform
        initialize_exercise
      else
        import_multi
      end
    end

    private

    def import_multi
      Zip::File.open(@zip.path) do |zip_file|
        zip_files = zip_file.filter { |entry| entry.name.match?(/\.zip$/) }
        begin
          zip_files.map! do |entry|
            store_zip_entry_in_tempfile entry
          end
          exercises = zip_files.map do |proforma_file|
            Import.call(zip: proforma_file, user: @user)
          end
          exercises.each(&:save)
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
    end

    def initialize_exercise
      @exercise = Exercise.new(
        title: @task.title,
        descriptions: [Description.new(text: @task.description, language: @task.language)],
        instruction: @task.internal_description,
        execution_environment: execution_environment,
        tests: tests,
        uuid: @task.uuid,
        exercise_files: task_files.values,
        user: @user
      )
    end

    def task_files
      @task_files ||= Hash[
        @task.all_files.reject { |file| file.id == 'ms-placeholder-file' }.map do |task_file|
          [task_file.id, exercise_file_from_task_file(task_file)]
        end
      ]
    end

    def exercise_file_from_task_file(task_file)
      ExerciseFile.new({
        full_file_name: task_file.filename,
        read_only: task_file.usage_by_lms.in?(%w[display download]),
        hidden: task_file.visible == 'no',
        role: task_file.internal_description
      }.tap do |params|
        if task_file.binary
          params[:attachment] = file_base64(task_file)
          params[:attachment_file_name] = task_file.filename
          params[:attachment_content_type] = task_file.mimetype
        else
          params[:content] = task_file.content
        end
      end)
    end

    def file_base64(file)
      "data:#{file.mimetype || 'image/jpeg'};base64,#{Base64.encode64(file.content)}"
    end

    def tests
      @task.tests.map do |test_object|
        Test.new(
          feedback_message: test_object.meta_data['feedback-message'],
          testing_framework: TestingFramework.where(
            name: test_object.meta_data['testing-framework'],
            version: test_object.meta_data['testing-framework-version']
          ).first_or_initialize,
          exercise_file: test_file(test_object)
        )
      end
    end

    def test_file(test_object)
      task_files.delete(test_object.files.first.id).tap { |file| file.purpose = 'test' }
    end

    def execution_environment
      ExecutionEnvironment.where(language: @task.proglang[:name], version: @task.proglang[:version]).first_or_initialize
    end
  end
end
