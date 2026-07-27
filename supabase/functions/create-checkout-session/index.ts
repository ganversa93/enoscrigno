// ════════════════════════════════════════════════════════════════
// ENOSCRIGNO — Edge Function: create-checkout-session
//
// Riceve la richiesta di upgrade a Premium dal frontend, crea (o
// riusa) un cliente Stripe per l'utente autenticato, e genera una
// sessione di pagamento Stripe Checkout (una pagina ospitata da
// Stripe stesso — l'app non vede né gestisce mai i dati della carta).
// Restituisce l'URL a cui reindirizzare il browser.
// ════════════════════════════════════════════════════════════════

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import Stripe from 'https://esm.sh/stripe@17?target=deno';

const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!;
const STRIPE_PRICE_ID   = Deno.env.get('STRIPE_PRICE_ID')!;
const SUPABASE_URL      = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const APP_URL           = Deno.env.get('APP_URL') || 'https://ganversa93.github.io/enosfera';

const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' });

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json({ error: 'Non autenticato' }, 401);

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: { user }, error: authErr } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''));
    if (authErr || !user) return json({ error: 'Non autenticato' }, 401);

    // Recupera o crea il cliente Stripe per questo utente
    const { data: profile } = await supabase.from('profiles').select('stripe_customer_id, full_name').eq('id', user.id).single();

    let customerId = profile?.stripe_customer_id;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: user.email,
        name: profile?.full_name || undefined,
        metadata: { supabase_user_id: user.id },
      });
      customerId = customer.id;
      await supabase.from('profiles').update({ stripe_customer_id: customerId }).eq('id', user.id);
    }

    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      mode: 'subscription',
      line_items: [{ price: STRIPE_PRICE_ID, quantity: 1 }],
      success_url: `${APP_URL}?premium=success`,
      cancel_url: `${APP_URL}?premium=cancelled`,
      client_reference_id: user.id,
    });

    return json({ url: session.url });
  } catch (err) {
    console.error('create-checkout-session error:', err);
    return json({ error: err.message || 'Errore interno' }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
