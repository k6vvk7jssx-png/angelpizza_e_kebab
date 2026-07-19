import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import MenuCatalog from '../src/components/MenuCatalog';
import { supabase } from '../src/lib/supabaseClient';

// Mock Supabase Client
jest.mock('../src/lib/supabaseClient', () => {
  const mockEq = jest.fn().mockResolvedValue({
    data: [
      { id: '1', name: 'ANGEL', description: 'Hamburger, edamer, bacon', price: 8.0, category: 'fastfood', is_available: true },
      { id: '2', name: 'Patatine Fritte', description: 'Rustiche con buccia', price: 3.5, category: 'pizze_rosse', is_available: true },
    ],
    error: null,
  });

  const mockSelect = jest.fn().mockReturnValue({
    eq: mockEq,
  });

  return {
    supabase: {
      from: jest.fn().mockReturnValue({
        select: mockSelect,
      }),
    },
  };
});

describe('MenuCatalog Component', () => {
  it('renders menu categories and items correctly', async () => {
    render(<MenuCatalog onAddToCart={jest.fn()} />);

    // Wait for the menu items to fetch and render
    await waitFor(() => {
      expect(screen.getByRole('heading', { name: 'Fast Food' })).toBeInTheDocument();
      expect(screen.getByRole('heading', { name: 'Pizze Rosse' })).toBeInTheDocument();
    });

    // Check specific items
    expect(screen.getByText('ANGEL')).toBeInTheDocument();
    expect(screen.getByText('Patatine Fritte')).toBeInTheDocument();
    expect(screen.getByText('€8.00')).toBeInTheDocument();
    expect(screen.getByText('€3.50')).toBeInTheDocument();
  });

  it('triggers onAddToCart callback when clicking add button', async () => {
    const handleAddToCart = jest.fn();
    render(<MenuCatalog onAddToCart={handleAddToCart} />);

    await waitFor(() => {
      expect(screen.getByText('ANGEL')).toBeInTheDocument();
    });

    // Find the add to cart button for the 'ANGEL' burger
    const addButtons = screen.getAllByRole('button', { name: /aggiungi/i });
    expect(addButtons.length).toBeGreaterThan(0);

    // Click the second add button (index 1) which corresponds to the fastfood item 'ANGEL'
    fireEvent.click(addButtons[1]);

    expect(handleAddToCart).toHaveBeenCalledWith(
      expect.objectContaining({
        id: '1',
        name: 'ANGEL',
        price: 8.0,
      })
    );
  });
});
