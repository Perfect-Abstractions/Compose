/**
 * Netlify Serverless Function to handle newsletter form submissions
 * 
 * This function securely handles ConvertKit API integration by keeping
 * the API key on the server side. It validates input, sanitizes data,
 * and handles errors gracefully following Netlify best practices.
 * 
 * @see https://docs.netlify.com/functions/overview/
 * @see https://developers.convertkit.com/#subscribe-to-a-form
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
    const newsletterFormId = process.env.NEWSLETTER_FORM_ID;
    const apiUrl = process.env.NEWSLETTER_API_URL || 'https://api.convertkit.com/v3';

    if (!newsletterApiKey || !newsletterFormId) {
      console.error('Newsletter API configuration missing:', {
        hasApiKey: !!newsletterApiKey,
        hasFormId: !!newsletterFormId,
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

    // Prepare subscriber data for ConvertKit
    const subscriberData = {
      email: email.trim().toLowerCase(),
      ...(firstName && { first_name: firstName.trim() }),
      ...(lastName && { last_name: lastName.trim() }),
      ...customFields,
    };

    // Call ConvertKit API with timeout
    // ConvertKit requires api_key as a query parameter
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000); // 10 second timeout

    try {
      const convertKitUrl = `${apiUrl}/forms/${newsletterFormId}/subscribe?api_key=${encodeURIComponent(newsletterApiKey)}`;
      const convertKitResponse = await fetch(convertKitUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(subscriberData),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      const convertKitData = await convertKitResponse.json();

      if (!convertKitResponse.ok) {
        console.error('ConvertKit API error:', {
          status: convertKitResponse.status,
          statusText: convertKitResponse.statusText,
          data: convertKitData,
        });
        
        // Don't expose internal API errors to client
        const errorMessage = convertKitData.message || 'Failed to subscribe. Please try again.';
        
        return {
          statusCode: convertKitResponse.status >= 400 && convertKitResponse.status < 500 
            ? convertKitResponse.status 
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
          data: convertKitData,
        }),
      };

    } catch (fetchError) {
      clearTimeout(timeoutId);
      
      if (fetchError.name === 'AbortError') {
        console.error('Request timeout to ConvertKit API');
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
