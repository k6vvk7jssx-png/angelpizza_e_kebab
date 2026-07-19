import { render, screen } from '@testing-library/react';

describe('Sample Test', () => {
  it('renders a heading', () => {
    render(<h1>Angels Livorno</h1>);
    const heading = screen.getByRole('heading', { name: /angels livorno/i });
    expect(heading).toBeInTheDocument();
    expect(1).toBe(1); // passing check
  });
});
