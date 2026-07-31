import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react';
import type { ReactElement, ReactNode } from 'react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { ToastProvider } from '@/components/ui';

/** Auth is mocked so the OTP page can be driven with a pending request present. */
const requestOtp = vi.fn().mockResolvedValue({});
const verifyOtp = vi.fn();
const mockAuth: Record<string, unknown> = {
  loginAsRole: vi.fn(),
  verifyOtp,
  requestOtp,
  pendingOtp: { identifier: '9876543210', type: 'phone', sessionId: 's1' },
  user: null,
  ready: true,
};

vi.mock('@/lib/auth/AuthContext', async (importOriginal) => {
  const actual = await importOriginal<Record<string, unknown>>();
  return { ...actual, useAuth: () => mockAuth, AUTH_IS_DEMO: false };
});

const { OtpVerificationPage } = await import('./OtpVerificationPage');

function renderPage(ui: ReactElement) {
  function Wrapper({ children }: { children: ReactNode }) {
    return (
      <ThemeProvider>
        <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
          <ToastProvider>
            <MemoryRouter>{children}</MemoryRouter>
          </ToastProvider>
        </QueryClientProvider>
      </ThemeProvider>
    );
  }
  return render(ui, { wrapper: Wrapper });
}

const boxes = () => screen.getAllByRole('textbox') as HTMLInputElement[];
const resendBtn = () => screen.getByRole('button', { name: /resend code/i });

/**
 * Advance the cooldown one second per `act` block. The countdown re-arms its
 * timeout from an effect, so the render must COMMIT before the next timeout
 * exists — a single bulk advance inside one `act` only ever fires one tick.
 */
async function tick(seconds: number) {
  for (let i = 0; i < seconds; i++) {
    await act(async () => {
      vi.advanceTimersByTime(1000);
    });
  }
}

beforeEach(() => {
  requestOtp.mockClear();
  mockAuth.pendingOtp = { identifier: '9876543210', type: 'phone', sessionId: 's1' };
});
afterEach(() => {
  cleanup();
  vi.useRealTimers();
});

describe('OTP entry — autofill and paste', () => {
  it('marks only the first box as the one-time-code target', () => {
    renderPage(<OtpVerificationPage />);
    const b = boxes();
    expect(b).toHaveLength(6);
    expect(b[0]).toHaveAttribute('autocomplete', 'one-time-code');
    // Repeating it would make the platform offer autofill on every box.
    b.slice(1).forEach((i) => expect(i).toHaveAttribute('autocomplete', 'off'));
  });

  it('every box is individually labelled for screen readers', () => {
    renderPage(<OtpVerificationPage />);
    boxes().forEach((i, n) => expect(i).toHaveAttribute('aria-label', `Digit ${n + 1} of 6`));
  });

  it('pasting a 6-digit SMS code fills all six boxes', () => {
    renderPage(<OtpVerificationPage />);
    fireEvent.paste(boxes()[0], { clipboardData: { getData: () => '482913' } });
    expect(boxes().map((i) => i.value)).toEqual(['4', '8', '2', '9', '1', '3']);
  });

  it('strips formatting when pasting (e.g. "482 913")', () => {
    renderPage(<OtpVerificationPage />);
    fireEvent.paste(boxes()[0], { clipboardData: { getData: () => '482 913' } });
    expect(boxes().map((i) => i.value).join('')).toBe('482913');
  });

  it('platform autofill delivering the whole code to one box is spread across all six', () => {
    renderPage(<OtpVerificationPage />);
    // iOS/Android hand the full code to the focused input; maxLength does not
    // constrain an autofilled value, and this used to be dropped entirely.
    fireEvent.change(boxes()[0], { target: { value: '135790' } });
    expect(boxes().map((i) => i.value).join('')).toBe('135790');
  });

  it('never overflows past six digits', () => {
    renderPage(<OtpVerificationPage />);
    fireEvent.paste(boxes()[0], { clipboardData: { getData: () => '1234567890' } });
    expect(boxes().map((i) => i.value).join('')).toBe('123456');
  });

  it('pasting into a later box fills forward from there', () => {
    renderPage(<OtpVerificationPage />);
    fireEvent.paste(boxes()[3], { clipboardData: { getData: () => '789' } });
    expect(boxes().map((i) => i.value)).toEqual(['', '', '', '7', '8', '9']);
  });

  it('still accepts single-digit typing', () => {
    renderPage(<OtpVerificationPage />);
    fireEvent.change(boxes()[0], { target: { value: '5' } });
    expect(boxes()[0].value).toBe('5');
    expect(boxes()[1].value).toBe('');
  });

  it('rejects non-numeric typing', () => {
    renderPage(<OtpVerificationPage />);
    fireEvent.change(boxes()[0], { target: { value: 'a' } });
    expect(boxes()[0].value).toBe('');
  });
});

describe('Resend code', () => {
  it('opens closed, with a live countdown (the server is already in cooldown)', () => {
    renderPage(<OtpVerificationPage />);
    const b = resendBtn();
    expect(b).toBeDisabled();
    expect(b).toHaveTextContent(/Resend code in \d+s/);
  });

  it('counts down and then enables', async () => {
    vi.useFakeTimers();
    renderPage(<OtpVerificationPage />);
    expect(resendBtn()).toHaveTextContent('Resend code in 60s');
    await tick(1);
    expect(resendBtn()).toHaveTextContent('Resend code in 59s');
    await tick(59);
    expect(resendBtn()).toBeEnabled();
    expect(resendBtn()).toHaveTextContent('Resend code');
  });

  it('actually calls the backend once enabled — it was a dead control before', async () => {
    vi.useFakeTimers();
    renderPage(<OtpVerificationPage />);
    await tick(60);
    await act(async () => {
      fireEvent.click(resendBtn());
    });
    expect(requestOtp).toHaveBeenCalledTimes(1);
    expect(requestOtp).toHaveBeenCalledWith('9876543210', 'phone');
  });

  it('clears the entered digits and restarts the cooldown after a resend', async () => {
    vi.useFakeTimers();
    renderPage(<OtpVerificationPage />);
    fireEvent.paste(boxes()[0], { clipboardData: { getData: () => '111111' } });
    await tick(60);
    await act(async () => {
      fireEvent.click(resendBtn());
    });
    expect(boxes().map((i) => i.value).join('')).toBe('');
    expect(resendBtn()).toBeDisabled();
    expect(screen.getByText(/A new code has been sent/i)).toBeInTheDocument();
  });

  it('surfaces the server message and stays closed when the backend refuses', async () => {
    vi.useFakeTimers();
    requestOtp.mockRejectedValueOnce(new Error('Too many OTP requests. Please wait before trying again.'));
    renderPage(<OtpVerificationPage />);
    await tick(60);
    await act(async () => {
      fireEvent.click(resendBtn());
    });
    expect(screen.getByText(/Too many OTP requests/i)).toBeInTheDocument();
    expect(resendBtn()).toBeDisabled();
  });

  it('is disabled outright when there is no pending request', () => {
    mockAuth.pendingOtp = null;
    renderPage(<OtpVerificationPage />);
    expect(resendBtn()).toBeDisabled();
  });
});
