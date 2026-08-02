'use strict';

document.addEventListener('DOMContentLoaded', function () {
  // ─── CSRF ───────────────────────────────────────────
  function getCsrfToken() {
    var match = document.cookie.match(/XSRF-TOKEN=([^;]+)/);
    return match ? decodeURIComponent(match[1]) : '';
  }

  // ─── fetch wrapper ─────────────────────────────────
  function apiFetch(url, options) {
    var opts = options || {};
    var headers = {
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
    };

    if (opts.method && opts.method !== 'GET') {
      headers['X-XSRF-TOKEN'] = getCsrfToken();
    }

    if (opts.body !== undefined && opts.body !== null && typeof opts.body === 'object') {
      headers['Content-Type'] = 'application/json';
      opts.body = JSON.stringify(opts.body);
    }

    Object.keys(opts.headers || {}).forEach(function (k) {
      headers[k] = opts.headers[k];
    });

    return fetch(url, {
      method: opts.method || 'GET',
      credentials: 'include',
      headers: headers,
      body: opts.body,
      redirect: opts.redirect,
    }).then(function (res) {
      if (res.status === 401) {
        window.location.href = '/login';
        return null;
      }
      return res;
    });
  }

  // ─── HTML escape ───────────────────────────────────
  function escapeHtml(str) {
    if (str === null || str === undefined) return '';
    var div = document.createElement('div');
    div.textContent = String(str);
    return div.innerHTML;
  }

  // ─── Flash message ─────────────────────────────────
  var flashTimer = null;
  function showFlash(message, isError) {
    var el = document.getElementById('flash');
    el.textContent = message;
    el.className = 'app-flash' + (isError ? ' app-flash--error' : '');
    el.hidden = false;
    if (flashTimer) clearTimeout(flashTimer);
    flashTimer = setTimeout(function () { el.hidden = true; }, 3000);
  }

  // ─── Task list ─────────────────────────────────────
  var currentTasks = [];

  function loadTasks() {
    var params = new URLSearchParams();
    var title = document.getElementById('filter-title').value;
    var status = document.getElementById('filter-status').value;
    var priority = document.getElementById('filter-priority').value;
    var sortEl = document.querySelector('input[name="due_date_sort"]:checked');
    var prioritySortEl = document.querySelector('input[name="priority_sort"]:checked');

    if (title) params.set('title', title);
    if (status) params.set('status', status);
    if (priority) params.set('priority', priority);
    if (prioritySortEl) params.set('priority_sort', prioritySortEl.value);
    if (sortEl) params.set('due_date_sort', sortEl.value);

    var qs = params.toString();
    var url = '/api/tasks' + (qs ? '?' + qs : '');

    apiFetch(url).then(function (res) {
      if (!res) return;
      if (!res.ok) {
        showFlash('タスクの読み込みに失敗しました', true);
        return;
      }
      return res.json();
    }).then(function (json) {
      if (!json) return;
      currentTasks = json.data;
      renderTasks(currentTasks);
    });
  }

  function renderTasks(tasks) {
    var tbody = document.getElementById('task-list');

    if (!tasks || tasks.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="empty-cell">タスクがありません</td></tr>';
      return;
    }

    tbody.innerHTML = tasks.map(function (task) {
      return '<tr>'
        + '<td class="title-cell">' + escapeHtml(task.title) + '</td>'
        + '<td>' + escapeHtml(task.status) + '</td>'
        + '<td>' + escapeHtml(task.priority) + '</td>'
        + '<td>' + (task.due_date || '-') + '</td>'
        + '<td class="text-right">'
        +   '<button class="app-link-btn" data-edit="' + task.id + '">編集</button> '
        +   '<button class="app-link-btn app-link-btn--danger" data-delete="' + task.id + '">削除</button>'
        + '</td>'
        + '</tr>';
    }).join('');

    tbody.querySelectorAll('[data-edit]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var id = Number(btn.getAttribute('data-edit'));
        var task = currentTasks.find(function (t) { return t.id === id; });
        if (task) openEditModal(task);
      });
    });

    tbody.querySelectorAll('[data-delete]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        deleteTask(Number(btn.getAttribute('data-delete')));
      });
    });
  }

  // ─── Modal ─────────────────────────────────────────
  function openCreateModal() {
    document.getElementById('modal-title').textContent = 'タスク作成';
    document.getElementById('task-id').value = '';
    document.getElementById('task-title-input').value = '';
    document.getElementById('task-description').value = '';
    document.getElementById('task-status').value = 'todo';
    document.getElementById('task-priority').value = 'medium';
    document.getElementById('task-due-date').value = '';
    document.getElementById('form-errors').hidden = true;
    document.getElementById('modal-overlay').hidden = false;
  }

  function openEditModal(task) {
    document.getElementById('modal-title').textContent = 'タスク編集';
    document.getElementById('task-id').value = task.id;
    document.getElementById('task-title-input').value = task.title;
    document.getElementById('task-description').value = task.description || '';
    document.getElementById('task-status').value = task.status;
    document.getElementById('task-priority').value = task.priority || 'medium';
    document.getElementById('task-due-date').value = task.due_date || '';
    document.getElementById('form-errors').hidden = true;
    document.getElementById('modal-overlay').hidden = false;
  }

  function closeModal() {
    document.getElementById('modal-overlay').hidden = true;
  }

  // ─── Save (create / update) ────────────────────────
  function saveTask(e) {
    e.preventDefault();
    var taskId = document.getElementById('task-id').value;
    var data = {
      title: document.getElementById('task-title-input').value,
      description: document.getElementById('task-description').value || null,
      status: document.getElementById('task-status').value,
      priority: document.getElementById('task-priority').value,
      due_date: document.getElementById('task-due-date').value || null,
    };

    var url = taskId ? '/api/tasks/' + taskId : '/api/tasks';
    var method = taskId ? 'PUT' : 'POST';

    apiFetch(url, { method: method, body: data }).then(function (res) {
      if (!res) return;
      if (res.status === 422) {
        return res.json().then(function (json) { showFormErrors(json.errors); });
      }
      if (!res.ok) {
        showFlash('保存に失敗しました', true);
        return;
      }
      closeModal();
      showFlash(taskId ? 'タスクを更新しました' : 'タスクを作成しました');
      loadTasks();
    });
  }

  function showFormErrors(errors) {
    var el = document.getElementById('form-errors');
    var messages = Object.keys(errors).reduce(function (acc, key) {
      return acc.concat(errors[key]);
    }, []);
    el.innerHTML = messages.map(function (m) { return '<p>' + escapeHtml(m) + '</p>'; }).join('');
    el.hidden = false;
  }

  // ─── Delete ────────────────────────────────────────
  function deleteTask(id) {
    if (!confirm('このタスクを削除しますか？')) return;

    apiFetch('/api/tasks/' + id, { method: 'DELETE' }).then(function (res) {
      if (!res) return;
      if (!res.ok) {
        showFlash('削除に失敗しました', true);
        return;
      }
      showFlash('タスクを削除しました');
      loadTasks();
    });
  }

  // ─── Logout ────────────────────────────────────────
  function logout() {
    apiFetch('/logout', { method: 'POST', redirect: 'manual' }).then(function () {
      window.location.href = '/login';
    }).catch(function () {
      window.location.href = '/login';
    });
  }

  // ─── Event bindings ────────────────────────────────
  document.getElementById('create-btn').addEventListener('click', openCreateModal);
  document.getElementById('cancel-btn').addEventListener('click', closeModal);
  document.getElementById('task-form').addEventListener('submit', saveTask);
  document.getElementById('logout-btn').addEventListener('click', logout);

  document.getElementById('filter-form').addEventListener('submit', function (e) {
    e.preventDefault();
    loadTasks();
  });

  document.getElementById('modal-overlay').addEventListener('click', function (e) {
    if (e.target === this) closeModal();
  });

  // ─── Init ──────────────────────────────────────────
  loadTasks();
});
