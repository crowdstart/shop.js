Promise = require 'broken'
requestAnimationFrame = require 'raf'
countryUtils = require '../utils/country'

emailRe = /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/

middleware =
  isRequired: (value) ->
    return value if value && value != ''

    throw new Error 'Required'

  isEmail: (value) ->
    return value unless value

    return value.toLowerCase() if emailRe.test value

    throw new Error 'Enter a valid email'

  isNewPassword: (value) ->
    if !@get 'user.currentPassword'
      throw new Error 'Current password required' if value
      return value

    return middleware.isPassword value

  isPassword: (value) ->
    unless value
      throw new Error 'Required'

    return value if value.length >= 6

    throw new Error 'Password must be atleast 6 characters long'

  matchesPassword: (value)->
    return value if !@get 'user.password'
    return value if value == @get 'user.password'

    throw new Error 'Passwords must match'

  splitName: (value) ->
    return value unless value

    parts     = value.trim().split ' '
    firstName = parts.shift()
    lastName  = parts.join ' '

    @set 'user.firstName', firstName
    @set 'user.lastName',  lastName

    value

  isPostalRequired: (value) ->
    if countryUtils.requiresPostalCode(@get('order.shippingAddress.country') || '') && (!value? || value == '')
      throw new Error "Required for Selected Country"

  isEcardGiftRequired: (value) ->
    return value if (!@get('order.gift') || @get('order.giftType') != 'ecard') || (value && value != '')

    throw new Error 'Required'

  isPostalRequired: (value) ->
    if countryUtils.requiresPostalCode(@get('order.shippingAddress.country') || '') && (!value? || value == '')
      throw new Error "Required for Selected Country"

    value

  requiresStripe: (value) ->
    throw new Error "Required" if @('order.type') == 'stripe' && (!value? || value == '')
    return value

  requireTerms: (value) ->
    if !value
      throw new Error 'Please read and agree to the terms and conditions.'
    value

  cardNumber: (value) ->
    return value unless value

    if @('order.type') != 'stripe'
      return value

    return new Promise (resolve, reject)->
      requestAnimationFrame ()->
        if $('input[name=number]').hasClass('jp-card-invalid')
          reject new Error('Enter a valid card number')
        resolve value

  expiration: (value) ->
    return value unless value

    if @('order.type') != 'stripe'
      return value

    date = value.split '/'
    if date.length < 2
      throw new Error('Enter a valid expiration date')

    @set('payment.account.month', (date[0]).trim?())
    @set('payment.account.year', ('' + (new Date()).getFullYear()).substr(0, 2) + (date[1]).trim?())

    return new Promise (resolve, reject)->
      requestAnimationFrame ()->
        if $('input[name=expiry]').hasClass('jp-card-invalid')
          reject new Error('Enter a valid expiration date')
        resolve value

  cvc: (value) ->
    return value unless value

    if @('order.type') != 'stripe'
      return value

    return new Promise (resolve, reject)->
      requestAnimationFrame ()->
        if $('input[name=cvc]').hasClass('jp-card-invalid')
          reject new Error('Enter a valid CVC number')
        resolve value

  agreeToTerms: (value) ->
    if value == true
      return value

    throw new Error 'Agree to the terms and conditions'

module.exports = middleware
