'use strict';

/**
 * limbs/thai-geo.js - Thai GeoTool Stub
 *
 * provides basic geocoding for Thai addresses, districts, and provinces.
 * Currently backed by a small in-memory dataset for verification.
 */

const GEO_DATA = {
  'กรุงเทพมหานคร': {
    province: 'กรุงเทพมหานคร',
    amphoe: 'เขตพระนคร',
    tambon: 'พระบรมมหาราชวัง',
    zipcode: '10200',
    lat: 13.7563,
    lon: 100.4975
  },
  'เชียงใหม่': {
    province: 'เชียงใหม่',
    amphoe: 'เมืองเชียงใหม่',
    tambon: 'ศรีภูมิ',
    zipcode: '60000',
    lat: 18.7883,
    lon: 98.9853
  },
  'ภูเก็ต': {
    province: 'ภูเก็ต',
    amphoe: 'เมืองภูเก็ต',
    tambon: 'ตลาดใหญ่',
    zipcode: '83000',
    lat: 7.8804,
    lon: 98.3923
  },
  'ขอนแก่น': {
    province: 'ขอนแก่น',
    amphoe: 'เมืองขอนแก่น',
    tambon: 'ในเมือง',
    zipcode: '40000',
    lat: 15.2837,
    lon: 102.8237
  },
  'อำเภอเมืองเชียงใหม่': {
    province: 'เชียงใหม่',
    amphoe: 'เมืองเชียงใหม่',
    tambon: 'ศรีภูมิ',
    zipcode: '60000',
    lat: 18.7883,
    lon: 98.9853
  }
};

/**
 * geocode(query)
 * Returns geo data if a match is found in the dataset, otherwise a default "unknown" result.
 */
function geocode(query) {
  if (!query) return { error: 'Empty query' };

  const normalized = query.trim();

  // Exact match
  if (GEO_DATA[normalized]) {
    return { ...GEO_DATA[normalized], query: normalized, match: 'exact' };
  }

  // Partial match (search for keywords in keys)
  for (const key in GEO_DATA) {
    if (normalized.includes(key) || key.includes(normalized)) {
      return { ...GEO_DATA[key], query: normalized, match: 'partial' };
    }
  }

  return {
    province: 'ไม่ทราบ',
    amphoe: 'ไม่ทราบ',
    tambon: 'ไม่ทราบ',
    zipcode: '00000',
    query: normalized,
    match: 'none'
  };
}

module.exports = { geocode };
