/**
 * Netlify Serverless Function to handle newsletter form submissions
 * 
 * This function securely handles Kit API integration by keeping
 * the API key on the server side. It validates input, sanitizes data,
 * and handles errors gracefully following Netlify best practices.
 * 
 * @see https://docs.netlify.com/functions/overview/
 * @see https://developers.kit.com/api-reference/subscribers/create-a-subscriber
 */

exports.handler = async (event, context) => {
  // Only allow POST requests
  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
      body: JSON.stringify({ error: 'Method not allowed' }),
    };
  }

  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
      body: '',
    };
  }

  try {
    // Parse request body
    let body;
    try {
      body = JSON.parse(event.body);
    } catch (parseError) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify({ error: 'Invalid JSON in request body' }),
      };
    }

    const { email, firstName, lastName, ...customFields } = body;

    // Validate email (RFC 5322 compliant regex)
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!email || !emailRegex.test(email)) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify({ error: 'Valid email is required' }),
      };
    }

    // Get configuration from environment variables
    const newsletterApiKey = process.env.NEWSLETTER_API_KEY;
    const apiUrl = process.env.NEWSLETTER_API_URL || 'https://api.kit.com/v4';

    if (!newsletterApiKey) {
      console.error('Newsletter API configuration missing:', {
        hasApiKey: !!newsletterApiKey,
      });
      return {
        statusCode: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: JSON.stringify({ error: 'Server configuration error' }),
      };
    }

    // Prepare subscriber data for Kit API v4
    // Kit API expects: email_address, first_name, state, fields
    const subscriberData = {
      email_address: email.trim().toLowerCase(),
      ...(firstName && { first_name: firstName.trim() }),
      state: 'active', // Default to active state
      ...(Object.keys(customFields).length > 0 && {
        fields: Object.entries(customFields).reduce((acc, [key, value]) => {
          // Only include non-empty custom fields
          if (value !== null && value !== undefined && value !== '') {
            acc[key] = String(value);
          }
          return acc;
        }, {}),
      }),
    };

    // Call Kit API with timeout
    // Kit API requires X-Kit-Api-Key header
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000); // 10 second timeout

    try {
      const kitUrl = `${apiUrl}/subscribers`;
      const kitResponse = await fetch(kitUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Kit-Api-Key': newsletterApiKey,
        },
        body: JSON.stringify(subscriberData),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      const kitData = await kitResponse.json();

      if (!kitResponse.ok) {
        console.error('Kit API error:', {
          status: kitResponse.status,
          statusText: kitResponse.statusText,
          data: kitData,
        });
        
        // Don't expose internal API errors to client
        const errorMessage = kitData.message || 'Failed to subscribe. Please try again.';
        
        return {
          statusCode: kitResponse.status >= 400 && kitResponse.status < 500 
            ? kitResponse.status 
            : 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
          body: JSON.stringify({ 
            error: errorMessage,
          }),
        };
      }

      // Success response
      return {
        statusCode: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': process.env.NODE_ENV === 'production' 
            ? process.env.URL || '*' 
            : '*',
          'Access-Control-Allow-Methods': 'POST',
          'Access-Control-Allow-Headers': 'Content-Type',
        },
        body: JSON.stringify({ 
          success: true,
          message: 'Successfully subscribed!',
          data: kitData,
        }),
      };

    } catch (fetchError) {
      clearTimeout(timeoutId);
      
      if (fetchError.name === 'AbortError') {
        console.error('Request timeout to Kit API');
        return {
          statusCode: 504,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
          body: JSON.stringify({ 
            error: 'Request timeout. Please try again.',
          }),
        };
      }

      throw fetchError; // Re-throw to be caught by outer catch
    }

  } catch (error) {
    console.error('Function error:', {
      message: error.message,
      stack: error.stack,
    });
    
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
      body: JSON.stringify({ 
        error: 'Internal server error',
        message: process.env.NODE_ENV === 'development' ? error.message : undefined,
      }),
    };
  }
};
