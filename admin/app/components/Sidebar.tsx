'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';

const NAV = [
  { href: '/dashboard', label: 'Dashboard', icon: '📊' },
  { href: '/restaurants', label: 'Restaurantes', icon: '🍽️' },
  { href: '/orders', label: 'Pedidos', icon: '📦' },
  { href: '/users', label: 'Usuários', icon: '👥' },
  { href: '/zones', label: 'Zonas', icon: '🗺️' },
  { href: '/coupons', label: 'Cupons', icon: '🏷️' },
  { href: '/settings', label: 'Configurações', icon: '⚙️' },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  const logout = () => {
    localStorage.removeItem('bitfood_token');
    router.push('/login');
  };

  return (
    <aside className="w-60 min-h-screen bg-white border-r border-gray-200 flex flex-col">
      {/* Logo */}
      <div className="p-5 border-b border-gray-200">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-primary rounded-lg flex items-center justify-center text-white font-bold text-sm">B</div>
          <span className="font-bold text-lg text-ifood-dark">BitFood</span>
          <span className="text-xs text-gray-400 ml-1">Admin</span>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 p-3">
        {NAV.map(item => {
          const active = pathname?.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg mb-1 text-sm font-medium transition-colors ${
                active
                  ? 'bg-red-50 text-primary'
                  : 'text-gray-600 hover:bg-gray-50 hover:text-ifood-dark'
              }`}
            >
              <span>{item.icon}</span>
              {item.label}
            </Link>
          );
        })}
      </nav>

      {/* Logout */}
      <div className="p-3 border-t border-gray-200">
        <button
          onClick={logout}
          className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-gray-500 hover:bg-red-50 hover:text-primary transition-colors"
        >
          <span>🚪</span> Sair
        </button>
      </div>
    </aside>
  );
}
