import { describe, expect, it } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '@/test/utils';
import { LoginPage } from './LoginPage';

// Runs under the default (demo) env. The live-build shape — mobile number +
// OTP only, no role explorer — is covered in lib/auth/production-auth.test.tsx.
describe('LoginPage (demo build)', () => {
  it('renders the welcome heading and role preview options', () => {
    renderWithProviders(<LoginPage />);
    expect(screen.getByText('Welcome back')).toBeInTheDocument();
    // Role preview cards present (e.g. School Admin).
    expect(screen.getAllByText(/School Admin/i).length).toBeGreaterThan(0);
  });

  it('exposes both preview and credentials sign-in tabs', () => {
    renderWithProviders(<LoginPage />);
    expect(screen.getByText('Explore by role')).toBeInTheDocument();
    expect(screen.getByText('Sign in')).toBeInTheDocument();
  });
});
