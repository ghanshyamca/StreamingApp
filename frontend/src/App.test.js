import { render, screen } from '@testing-library/react';
import App from './App';

test('renders landing hero heading', () => {
  render(<App />);
  const heading = screen.getByRole('heading', {
    name: /stream premium cinema from the comfort of anywhere/i,
  });
  expect(heading).toBeInTheDocument();
});
