require './utils/patches'

Promise         = require 'broken'
riot            = require 'riot'
extend          = require 'extend'
window?.riot    = riot

refer           = require 'referential'
store           = require './utils/store'
{Cart}          = require 'commerce.js'

Crowdstart      = require 'hanzo.js'

m               = require './mediator'
Events          = require './events'
analytics       = require './utils/analytics'

Shop                = require './shop'
Shop.Forms          = require './forms'
Shop.Events         = Events
Shop.Widgets        = require './widgets'
Shop.Controls       = require './controls'
Shop.CrowdControl   = require 'crowdcontrol'
Shop.Referential    = refer

# Monkey Patch common utils onto every View/Instance
Shop.CrowdControl.Views.View.prototype.renderCurrency = require('./utils/currency').renderUICurrencyFromJSON
Shop.CrowdControl.Views.View.prototype.renderDate = require('./utils/dates')

Shop.use = (templates) ->
  Shop.Controls.Control::errorHtml = templates.Controls.Error if templates?.Controls?.Error
  Shop.Controls.Text::html         = templates.Controls.Text  if templates?.Controls?.Text

# Format of opts.config
# {
#   ########################
#   ### Order Overrides ####
#   ########################
#   currency:           string (3 letter ISO code)
#   taxRate:            number (decimal) taxRate, overridden by opts.taxRates
#   shippingRate:       number (per item cost in cents or base unit for zero decimal currencies)
#   checkoutUrl:        string checkoutUrl for marketing emails
# }
#
# Format of opts.taxRates
# Tax rates are filtered based on exact string match of city, state, and country.
# Tax rates are evaluated in the order listed in the array.  This means if the first tax rate
# is matched, then the subsequent tax rates will not be evaluated.
# Therefore, list tax rates from specific to general
#
# If no city, state, or country is set, then the tax rate will be used if evaluated
#
# [
#   {
#     taxRate:  number (decimal tax rate)
#     city:     null or string (name of city where tax is charged)
#     state:    null or string (2 digit Postal code of US state or name of non-US state where tax is charged)
#     country:  null or string (2 digit ISO country code eg. 'us' where tax is charged)
#   }
# ]
#
#Format of opts.referralProgram
# Referral Program Object

Shop.riot = riot

Shop.analytics = analytics

Shop.isEmpty = ->
  items = @data.get 'order.items'
  return items.length == 0

getQueries = ()->
  search = /([^&=]+)=?([^&]*)/g
  q = window.location.href.split('?')[1]
  qs = {}
  if q?
    while (match = search.exec(q))
      k = match[1]
      try
        k = decodeURIComponent k
      v = match[2]
      try
        v = decodeURIComponent v
      catch err
      qs[k] = v

  return qs

getReferrer = (qs)->
  if qs.referrer?
    store.set 'referrer', qs.referrer
    return q.referrer
  else
    return store.get 'referrer'

getMCIds = (qs)->
  return [qs['mc_eid'], qs['mc_cid']]

Shop.start = (opts = {}) ->
  unless opts.key?
    throw new Error 'Please specify your API Key'

  Shop.Forms.register()
  Shop.Widgets.register()
  Shop.Controls.register()

  queries = getQueries()
  referrer = getReferrer(queries) ? opts.order?.referrer

  items = store.get 'items'
  cartId = store.get 'cartId'

  @data = refer
    taxRates:       opts.taxRates || []
    order:
      giftType:     'physical'
      type:         'stripe'
      shippingRate: opts.config?.shippingRate   || opts.order?.shippingRate  || 0
      taxRate:      opts.config?.taxRate        || opts.order?.taxRate       || 0
      currency:     opts.config?.currency       || opts.order?.currency      || 'usd'
      referrerId:   referrer
      shippingAddress:
        country: 'us'
      discount: 0
      tax: 0
      subtotal: 0
      total: 0
      items: items ? []
      cartId: cartId ? null

  data = @data.get()
  for k, v of opts
    if opts[k]
      if !data[k]?
        data[k] = opts[k]
      else
        extend data[k], opts[k]

  @data.set data

  # load multipage partial checkout data
  checkoutUser = store.get 'checkout-user'
  checkoutShippingAddress = store.get 'checkout-shippingAddress'

  if checkoutUser
    @data.set 'user', checkoutUser
    store.remove 'checkout-user'

  if checkoutShippingAddress
    @data.set 'order.shippingAddress', checkoutShippingAddress
    store.remove 'checkout-shippingAddress'

  @client = new Crowdstart.Api
    key:      opts.key
    endpoint: opts.endpoint

  @cart = new Cart @client, @data

  @cart.onCart = ()=>
    store.set 'cartId', @data.get 'order.cartId'
    [_, mcCId] = getMCIds queries
    @cart._cartUpdate
      mailchimp:
        campaignId:     mcCId
        checkoutUrl:    opts.config?.checkoutUrl

    # try get userId
    @client.account.get().then (res)=>
      @cart._cartUpdate
        userId:     res.email
        userEmail:  res.email

  tagNames = []
  for k, v of Shop.Forms
    tagNames.push(v.prototype.tag) if v.prototype.tag?

  tags = riot.mount tagNames.join(', '),
    data:   @data
    cart:   @cart
    client: @client

  riot.update = ->
    for tag in tags
      tag.update()

  @cart.onUpdate = (item)=>
    items = @data.get 'order.items'
    store.set 'items', items
    if item?
      m.trigger Events.UpdateItem, item
    riot.update()

  ps = []
  for tag in tags
    p = new Promise (resolve)->
      tag.one 'updated', ->
        resolve()
    ps.push p

  Promise.settle(ps).then(->
    m.trigger Events.Ready
  ).catch (err)->
    window?.Raven?.captureException err

  # quite hacky
  m.data = @data
  m.on Events.SetData, (@data)=>
    @cart.invoice()

  m.on Events.DeleteLineItem, (item)->
    id = item.get 'id'
    Shop.setItem id, 0

  m.trigger Events.SetData, @data

  m.on 'error', (err)->
    console.log err
    window?.Raven?.captureException err

  # Fix incompletely loaded items
  if items? && items.length > 0
    for item in items
      if item.id?
        @cart.load item.id
      else if item.productId?
        @cart.refresh item.productId

  # Force update
  riot.update()

  return m

waits           = 0
itemUpdateQueue = []

Shop.initCart = ()->
  @cart.initCart()

Shop.setItem = (id, quantity, locked=false)->
  m.trigger Events.TryUpdateItem, id
  p = @cart.set id, quantity, locked
  if @promise != p
    @promise = p
    @promise.then(=>
      riot.update()
      m.trigger Events.UpdateItems, @data.get 'order.items'
    ).catch (err)->
      window?.Raven?.captureException err

Shop.getItem = (id)->
  return @cart.get id

module.exports = Crowdstart.Shop = Shop
