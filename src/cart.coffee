class Cart
  constructor: ->
    riot.observable @
    @items = []

  add: (item) ->
    @items.push item

  remove: (item) ->
    for _item, index in @items by -1
      if item.id == _item.id
        return @items.splice index, 1

  get: ->
    items = []

    subtotal = 0

    for item in @items
      items.push items
      subtotal += item.quantity * item.price
    return {
      items:    items
      subtotal: subtotal
    }

module.exports = new Cart

#leave this here for now
m = require './mediator'
Events = require './events'

m.on Events.SetData, (@data) ->
  calculateInvoice.call @

m.on Events.UpdateItems, ->
  calculateInvoice.call @

m.on Events.ChangeSuccess, (key, value)->
  if key.indexOf('quantity') >= 0 || key.indexOf('city') >= 0 || key.indexOf('state') >= 0 || key.indexOf('country') >= 0
    calculateInvoice.call @

calculateInvoice = ->
  items    =   @data.get 'order.items'
  subtotal = -(@data.get 'order.discount') ? 0

  for item in items
    subtotal += item.price * item.quantity

  @data.set 'order.subtotal', subtotal

  taxRate      = (@data.get 'order.taxRate')      ? 0
  shippingRate = (@data.get 'order.shippingRate') ? 0

  tax = Math.ceil (taxRate ? 0) * subtotal
  shipping = shippingRate

  @data.set 'order.shipping', shipping
  @data.set 'order.tax', tax
  @data.set 'order.total', subtotal + shipping + tax