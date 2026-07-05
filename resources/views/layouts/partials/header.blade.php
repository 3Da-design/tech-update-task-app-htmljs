<header class="app-header">
  <div class="app-header__inner">
    <div class="app-header__brand">
      @auth
        <span class="app-header__user">{{ Auth::user()->name }}</span>
      @else
        <a href="{{ route('login') }}" class="app-header__user hover:text-gray-200">
          {{ config('app.name', 'Laravel') }}
        </a>
      @endauth
    </div>

    <nav class="app-header__nav">
      @auth
        <a href="/app/tasks.html" class="app-nav-link">
          タスク一覧
        </a>
        <a
          href="{{ route('profile.edit') }}"
          @class(['app-nav-link', 'app-nav-link--active' => request()->routeIs('profile.*')])
        >
          プロフィール
        </a>
        <form method="POST" action="{{ route('logout') }}" class="inline">
          @csrf
          <button type="submit" class="app-header__logout">ログアウト</button>
        </form>
      @else
        <a href="{{ route('login') }}" class="app-nav-link">ログイン</a>
        @if (Route::has('register'))
          <a href="{{ route('register') }}" class="app-nav-link">新規登録</a>
        @endif
      @endauth
    </nav>
  </div>
</header>
