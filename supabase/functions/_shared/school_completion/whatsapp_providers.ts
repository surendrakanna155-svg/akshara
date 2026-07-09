export type WhatsAppProviderType = "stub" | "msg91" | "gupshup";

export interface WhatsAppProviderConfig {
  provider: WhatsAppProviderType;
  senderId: string | null;
  apiKeyRef: string | null;
  templateNamespace: string | null;
  isActive: boolean;
}

export interface WhatsAppSendPayload {
  toPhone: string;
  templateId: string;
  variables?: Record<string, string>;
  body?: string;
}

export interface WhatsAppSendResult {
  success: boolean;
  providerRef: string | null;
  error: string | null;
}

export async function sendWhatsAppMessage(
  config: WhatsAppProviderConfig,
  payload: WhatsAppSendPayload,
): Promise<WhatsAppSendResult> {
  if (!config.isActive) {
    return { success: false, providerRef: null, error: "WhatsApp provider is inactive" };
  }

  switch (config.provider) {
    case "stub":
      // GAP-P1-9: "stub" is the fallback for a school that has never configured
      // a real WhatsApp provider (see whatsAppConfigToRuntime's default). It
      // used to report success:true, which fabricated 100% delivery on every
      // dashboard for a school that never sent a single real message. Report
      // the truth instead: nothing was actually sent.
      return {
        success: false,
        providerRef: null,
        error: "WhatsApp provider is not configured for this school",
      };
    case "msg91":
      return await sendViaMsg91(config, payload);
    case "gupshup":
      return await sendViaGupshup(config, payload);
    default:
      return { success: false, providerRef: null, error: `Unknown provider: ${config.provider}` };
  }
}

async function sendViaMsg91(
  config: WhatsAppProviderConfig,
  payload: WhatsAppSendPayload,
): Promise<WhatsAppSendResult> {
  const apiKey = config.apiKeyRef ?? Deno.env.get("MSG91_API_KEY");
  if (!apiKey || !config.senderId) {
    return { success: false, providerRef: null, error: "MSG91 not configured (api key or sender)" };
  }

  const response = await fetch("https://api.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      authkey: apiKey,
    },
    body: JSON.stringify({
      integrated_number: config.senderId,
      content_type: "template",
      payload: {
        to: payload.toPhone,
        type: "template",
        template: {
          name: payload.templateId,
          language: { code: "en" },
          components: payload.variables
            ? [{ type: "body", parameters: Object.values(payload.variables).map((v) => ({ type: "text", text: v })) }]
            : [],
        },
      },
    }),
  });

  if (!response.ok) {
    return { success: false, providerRef: null, error: await response.text() };
  }
  const data = await response.json() as { request_id?: string; message?: string };
  return { success: true, providerRef: data.request_id ?? data.message ?? null, error: null };
}

async function sendViaGupshup(
  config: WhatsAppProviderConfig,
  payload: WhatsAppSendPayload,
): Promise<WhatsAppSendResult> {
  const apiKey = config.apiKeyRef ?? Deno.env.get("GUPSHUP_API_KEY");
  if (!apiKey || !config.senderId) {
    return { success: false, providerRef: null, error: "Gupshup not configured (api key or sender)" };
  }

  const params = new URLSearchParams({
    channel: "whatsapp",
    source: config.senderId,
    destination: payload.toPhone,
    "src.name": config.templateNamespace ?? "AksharaERP",
    message: JSON.stringify({
      type: "text",
      text: payload.body ?? `Template: ${payload.templateId}`,
    }),
  });

  const response = await fetch(`https://api.gupshup.io/wa/api/v1/msg`, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      apikey: apiKey,
    },
    body: params,
  });

  if (!response.ok) {
    return { success: false, providerRef: null, error: await response.text() };
  }
  const data = await response.json() as { messageId?: string; status?: string };
  return { success: true, providerRef: data.messageId ?? data.status ?? null, error: null };
}
