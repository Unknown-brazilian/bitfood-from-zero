const axios = require('axios');

let cache = { brl: 0, usd: 0, at: 0 };

exports.getBTCPrice = async (currency = 'brl') => {
  const now = Date.now();
  if (now - cache.at < 60_000) return cache[currency.toLowerCase()] || 0;

  try {
    const { data } = await axios.get(
      'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=brl,usd',
      { timeout: 5000 }
    );
    cache = { brl: data.bitcoin.brl, usd: data.bitcoin.usd, at: now };
  } catch {}

  return cache[currency.toLowerCase()] || 0;
};
