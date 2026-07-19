# Angels Livorno Client Site - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a high-performance customer-facing website for Angels Livorno using Next.js and Supabase, matching the branding guidelines and supporting guest checkouts, OTP login, and Contrassegno (COD) payments.

**Architecture:** Monorepo subdirectory `client-web` running a Next.js (App Router) project connected to Supabase Client API. The app is divided into modular React components (Menu, Cart, Checkout) styled with Vanilla CSS to replicate the branding from `brand_style.md`.

**Tech Stack:** Next.js 15, React 19, TypeScript, Jest, React Testing Library, Supabase Client SDK, Vanilla CSS.

---

### Task 1: Initialize Next.js & Test Suite

**Files:**
- Create: `client-web/package.json`
- Create: `client-web/jest.config.ts`
- Create: `client-web/__tests__/example.test.tsx`

- [ ] **Step 1: Run create-next-app in client-web directory**
  Run: `npx -y create-next-app@latest client-web --typescript --eslint --app --src-dir --import-alias "@/*" --use-npm --yes`
  Expected: Next.js project scaffolded under `c:\Users\Utente\Desktop\Angels website\client-web`

- [ ] **Step 2: Install Jest and Testing Library dependencies**
  Run: `npm install -D jest jest-environment-jsdom @testing-library/react @testing-library/jest-dom @testing-library/dom ts-node` in `c:\Users\Utente\Desktop\Angels website\client-web`
  Expected: Development dependencies installed successfully.

- [ ] **Step 3: Create Jest Configuration**
  Write code to `client-web/jest.config.ts`:
  ```typescript
  import type { Config } from 'jest';
  import nextJest from 'next/jest.js';

  const createJestConfig = nextJest({
    dir: './',
  });

  const config: Config = {
    coverageProvider: 'v8',
    testEnvironment: 'jsdom',
    setupFilesAfterEnv: ['<rootDir>/jest.setup.ts'],
  };

  export default createJestConfig(config);
  ```

- [ ] **Step 4: Create Jest Setup File**
  Write code to `client-web/jest.setup.ts`:
  ```typescript
  import '@testing-library/jest-dom';
  ```

- [ ] **Step 5: Write a failing sample test**
  Write code to `client-web/__tests__/example.test.tsx`:
  ```typescript
  import { render, screen } from '@testing-library/react';

  describe('Sample Test', () => {
    it('renders a heading', () => {
      render(<h1>Angels Livorno</h1>);
      const heading = screen.getByRole('heading', { name: /angels livorno/i });
      expect(heading).toBeInTheDocument();
      // Force failure to verify TDD setup
      expect(1).toBe(2);
    });
  });
  ```

- [ ] **Step 6: Run test suite to verify failure**
  Run: `npm run test` or `npx jest` in `client-web`
  Expected: FAIL with `expect(1).toBe(2)`

- [ ] **Step 7: Fix the test to make it pass**
  Replace `expect(1).toBe(2);` with `expect(1).toBe(1);` in `client-web/__tests__/example.test.tsx`

- [ ] **Step 8: Run test suite to verify pass**
  Run: `npx jest` in `client-web`
  Expected: PASS

- [ ] **Step 9: Commit**
  Run:
  ```bash
  git add client-web/
  git commit -m "feat: init next.js client and jest testing framework"
  ```

---

### Task 2: Supabase Client Setup

**Files:**
- Create: `client-web/src/lib/supabase.ts`
- Create: `client-web/__tests__/supabase.test.ts`
- Create: `client-web/.env.local`

- [ ] **Step 1: Write Env Config**
  Write code to `client-web/.env.local`:
  ```env
  NEXT_PUBLIC_SUPABASE_URL=https://cavxvkwixbxbdvaasxpa.supabase.co
  NEXT_PUBLIC_SUPABASE_ANON_KEY=placeholder_anon_key
  ```

- [ ] **Step 2: Write failing Supabase client initialization test**
  Write code to `client-web/__tests__/supabase.test.ts`:
  ```typescript
  import { supabase } from '../src/lib/supabase';

  describe('Supabase Client', () => {
    it('is initialized with environment variables', () => {
      expect(supabase).toBeDefined();
      expect(supabase.auth).toBeDefined();
      // Force failure by checking incorrect config url
      expect(supabase.supabaseUrl).toBe('https://incorrect-url.supabase.co');
    });
  });
  ```

- [ ] **Step 3: Run test to verify failure**
  Run: `npx jest supabase.test` in `client-web`
  Expected: FAIL with URL mismatch or client not defined.

- [ ] **Step 4: Implement Supabase Client**
  Install package: `npm install @supabase/supabase-js`
  Write code to `client-web/src/lib/supabase.ts`:
  ```typescript
  import { createClient } from '@supabase/supabase-js';

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';

  export const supabase = createClient(supabaseUrl, supabaseAnonKey);
  ```

- [ ] **Step 5: Correct the test**
  Replace the failing assertion in `client-web/__tests__/supabase.test.ts`:
  ```typescript
  expect(supabase.supabaseUrl).toBe('https://cavxvkwixbxbdvaasxpa.supabase.co');
  ```

- [ ] **Step 6: Run test to verify pass**
  Run: `npx jest supabase.test` in `client-web`
  Expected: PASS

- [ ] **Step 7: Commit**
  Run:
  ```bash
  git add client-web/
  git commit -m "feat: setup supabase client with env credentials"
  ```

---

### Task 3: Menu Catalog Component (TDD)

**Files:**
- Create: `client-web/src/components/MenuCatalog.tsx`
- Create: `client-web/__tests__/MenuCatalog.test.tsx`

- [ ] **Step 1: Write failing component test**
  Write code to `client-web/__tests__/MenuCatalog.test.tsx`:
  ```typescript
  import { render, screen, fireEvent } from '@testing-library/react';
  import MenuCatalog from '../src/components/MenuCatalog';

  const mockItems = [
    { id: 1, name: 'Panino Kebab', price: 5.00, category: 'fastfood', description: 'Kebab wrap' },
    { id: 32, name: 'Pizza Margherita', price: 7.00, category: 'pizze', description: 'Pizza class' }
  ];

  describe('MenuCatalog', () => {
    it('renders categories and filters items', () => {
      const handleAdd = jest.fn();
      render(<MenuCatalog items={mockItems} onAddToCart={handleAdd} />);
      
      // Verify both items show initially
      expect(screen.getByText('Panino Kebab')).toBeInTheDocument();
      expect(screen.getByText('Pizza Margherita')).toBeInTheDocument();

      // Click on "Pizze" category filter
      const pizzeTab = screen.getByText('Pizze');
      fireEvent.click(pizzeTab);

      // Pizza should be in document, Kebab should be filtered out
      expect(screen.queryByText('Panino Kebab')).not.toBeInTheDocument();
      expect(screen.getByText('Pizza Margherita')).toBeInTheDocument();

      // Click Add to Cart
      const addButton = screen.getAllByRole('button', { name: /aggiungi/i })[0];
      fireEvent.click(addButton);
      expect(handleAdd).toHaveBeenCalledWith(mockItems[1]); // only pizza should be visible now
    });
  });
  ```

- [ ] **Step 2: Run test to verify failure**
  Run: `npx jest MenuCatalog.test` in `client-web`
  Expected: FAIL (component not found)

- [ ] **Step 3: Implement MenuCatalog Component**
  Write code to `client-web/src/components/MenuCatalog.tsx`:
  ```typescript
  import React, { useState } from 'react';

  interface MenuItem {
    id: number;
    name: string;
    price: number;
    category: string;
    description?: string;
  }

  interface Props {
    items: MenuItem[];
    onAddToCart: (item: MenuItem) => void;
  }

  export default function MenuCatalog({ items, onAddToCart }: Props) {
    const [activeCategory, setActiveCategory] = useState('all');

    const categories = [
      { id: 'all', name: 'Tutto' },
      { id: 'fastfood', name: 'Fast Food' },
      { id: 'pizze', name: 'Pizze' },
      { id: 'specialita', name: 'Specialità' }
    ];

    const filteredItems = activeCategory === 'all' 
      ? items 
      : items.filter(item => item.category === activeCategory);

    return (
      <div className="menu-container">
        <div className="category-tabs">
          {categories.map(cat => (
            <button 
              key={cat.id} 
              className={`category-tab ${activeCategory === cat.id ? 'active' : ''}`}
              onClick={() => setActiveCategory(cat.id)}
            >
              {cat.name}
            </button>
          ))}
        </div>

        <div className="menu-grid">
          {filteredItems.map(item => (
            <div key={item.id} className="menu-card">
              <div className="menu-card-header">
                <span className="menu-card-title">{item.name}</span>
                <span className="menu-card-price">€ {item.price.toFixed(2)}</span>
              </div>
              {item.description && <p className="menu-card-desc">{item.description}</p>}
              <div className="menu-card-footer">
                <button className="add-to-cart" onClick={() => onAddToCart(item)}>
                  Aggiungi
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }
  ```

- [ ] **Step 4: Run test to verify pass**
  Run: `npx jest MenuCatalog.test` in `client-web`
  Expected: PASS

- [ ] **Step 5: Commit**
  Run:
  ```bash
  git add client-web/
  git commit -m "feat: add MenuCatalog component with filtering and TDD"
  ```
