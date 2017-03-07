defmodule Que.Job do
  ## Note: Update Que.Persistence.Mnesia after changing these values

  defstruct  [:id, :uuid, :arguments, :worker, :status, :ref, :pid]

  @statuses  [:queued, :started, :failed, :completed]
  @moduledoc false


  ## Module definition for Que.Job struct to manage a Job's state.
  ## Meant only for internal usage, and not for the Public API.


  # Creates a new Job struct with defaults
  def new(worker, args) do
    %Que.Job{
      uuid:       UUID.uuid4(),
      status:     :queued,
      worker:     worker,
      arguments:  args
    }
  end



  # Update the Job status to one of the predefined values in @statuses
  def set_status(job, status) when status in @statuses do
    %{ job | status: status }
  end



  # Updates the Job struct with new status and spawns & monitors a new Task
  # under the TaskSupervisor which executes the perform method with supplied
  # arguments
  def perform(job) do
    Que.__log__("Starting #{job}")

    {:ok, pid} =
      do_task(fn ->
        job.worker.perform(job.arguments)
      end)

    %{ job | status: :started, pid: pid, ref: Process.monitor(pid) }
  end



  # Handles Job Success, Calls appropriate worker method and updates the job
  # status to :completed
  def handle_success(job) do
    Que.__log__("Completed #{job}")

    do_task(fn ->
      job.worker.on_success(job.arguments)
    end)

    %{ job | status: :completed, pid: nil, ref: nil }
  end



  # Handles Job Failure, Calls appropriate worker method and updates the job
  # status to :failed
  def handle_failure(job, err) do
    Que.__log__("Failed #{job}")

    do_task(fn ->
      job.worker.on_failure(job.arguments, err)
    end)

    %{ job | status: :failed, pid: nil, ref: nil }
  end



  # Off-load tasks to custom Que.TaskSupervisor
  defp do_task(fun) do
    Task.Supervisor.start_child(Que.TaskSupervisor, fun)
  end
end



defimpl String.Chars, for: Que.Job do
  ## Implementing the String.Chars protocol for Que.Job structs

  def to_string(job) do
    "Job # #{job.id} with #{ExUtils.Module.name(job.worker)}"
  end
end
