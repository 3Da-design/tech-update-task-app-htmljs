<?php

namespace App\Services;

use App\Models\Task;
use App\Repositories\Contracts\TaskRepositoryInterface;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\ModelNotFoundException;

class TaskService
{
  public function __construct(
    private TaskRepositoryInterface $tasks,
  ) {}

  public function currentUserId(): int
  {
    $id = auth()->id();

    if ($id === null) {
      throw new AuthenticationException;
    }

    return (int) $id;
  }

  public function listForDefaultUser(array $query): Collection
  {
    $userId = $this->currentUserId();

    return $this->tasks->getFiltered($userId, $this->normalizeListFilters($query));
  }

  public function createForDefaultUser(array $data): Task
  {
    unset($data['user_id']);
    $userId = $this->currentUserId();

    return $this->tasks->create($userId, $this->normalizeTaskPayload($data));
  }

  public function findForDefaultUser(int $taskId): Task
  {
    $userId = $this->currentUserId();
    $task = $this->tasks->findById($userId, $taskId);

    if ($task === null) {
      throw (new ModelNotFoundException)->setModel(Task::class, [$taskId]);
    }

    return $task;
  }

  /**
   * @param  array<string, mixed>  $data
   */
  public function updateForDefaultUser(int $taskId, array $data): Task
  {
    unset($data['user_id']);
    $task = $this->findForDefaultUser($taskId);

    return $this->tasks->update($task, $this->normalizeTaskPayload($data));
  }

  public function deleteForDefaultUser(int $taskId): void
  {
    $task = $this->findForDefaultUser($taskId);
    $this->tasks->delete($task);
  }

  /**
   * @param  array<string, mixed>  $query
   * @return array{title?: string, status?: string, priority?: string, priority_sort?: string, due_date_sort?: string}
   */
  private function normalizeListFilters(array $query): array
  {
    $filters = [];

    if (isset($query['title']) && is_string($query['title'])) {
      $title = trim($query['title']);
      if ($title !== '') {
        $filters['title'] = $title;
      }
    }

    if (isset($query['status']) && is_string($query['status'])) {
      $status = trim($query['status']);
      if ($status !== '') {
        $filters['status'] = $status;
      }
    }

    if (isset($query['priority']) && is_string($query['priority'])) {
      $priority = trim($query['priority']);
      if ($priority !== '') {
        $filters['priority'] = $priority;
      }
    }

    if (isset($query['priority_sort']) && $query['priority_sort'] === 'desc') {
      $filters['priority_sort'] = 'desc';
    } elseif (isset($query['priority_sort']) && $query['priority_sort'] === 'asc') {
      $filters['priority_sort'] = 'asc';
    }

    if (isset($query['due_date_sort']) && $query['due_date_sort'] === 'desc') {
      $filters['due_date_sort'] = 'desc';
    } elseif (isset($query['due_date_sort']) && $query['due_date_sort'] === 'asc') {
      $filters['due_date_sort'] = 'asc';
    }

    return $filters;
  }

  /**
   * @param  array<string, mixed>  $data
   * @return array<string, mixed>
   */
  private function normalizeTaskPayload(array $data): array
  {
    $allowed = ['title', 'description', 'status', 'priority', 'due_date'];
    $data = array_intersect_key($data, array_flip($allowed));

    if (array_key_exists('title', $data) && is_string($data['title'])) {
      $data['title'] = trim($data['title']);
    }

    if (array_key_exists('description', $data)) {
      $desc = $data['description'];
      if ($desc === null || $desc === '') {
        $data['description'] = null;
      } elseif (is_string($desc)) {
        $trimmed = trim($desc);
        $data['description'] = $trimmed === '' ? null : $trimmed;
      }
    }

    return $data;
  }
}
