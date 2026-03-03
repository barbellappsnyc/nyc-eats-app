import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const payload = await req.json()
    const event = payload.event

    // 1. Listen for subscriptions AND repeatable consumable purchases
    if (event.type === 'INITIAL_PURCHASE' || event.type === 'RENEWAL' || event.type === 'NON_RENEWING_PURCHASE') {
      
      const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '' 
      )

      const userId = event.app_user_id;
      const productId = event.product_id;

      let skuType = '';
      let maxPages = 0;
      let coverColor = 'slate';

      // 2. The exact translation dictionary
      if (productId === 'nyceats_diplomat') {
        skuType = 'diplomat_book';
        maxPages = 21; // Cover + 20 pages
        coverColor = 'navy';
      } else if (productId === 'nyceats_standard') {
        skuType = 'standard_book';
        maxPages = 6;  // Cover + 5 pages
        coverColor = 'slate';
      } else if (productId === 'nyceats_single') {
        skuType = 'single_page';
        maxPages = 1;  // Just the visa page
        coverColor = 'none'; // No physical cover needed for a loose page
      } else {
        // If it's an unknown product, safely ignore it so RevenueCat doesn't retry
        return new Response(JSON.stringify({ success: true, note: 'Ignored unknown product' }), { status: 200 })
      }

      // 3. We use INSERT instead of UPSERT so users can hoard multiple books/pages
      const { error } = await supabaseAdmin
        .from('user_passport_books')
        .insert({
          user_id: userId,
          sku_type: skuType,
          status: 'active',
          max_pages: maxPages,
          cover_color: coverColor
        })

      if (error) {
        return new Response(JSON.stringify({ error: error.message }), { status: 400 })
      }
    }

    return new Response(JSON.stringify({ success: true }), { status: 200 })
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Internal Server Error' }), { status: 500 })
  }
})