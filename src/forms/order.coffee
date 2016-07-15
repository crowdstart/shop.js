CrowdControl = require 'crowdcontrol'
riot = require 'riot'
m = require '../mediator'
Events = require '../events'
refer = require 'referential'

module.exports = class OrderForm extends CrowdControl.Views.Form
  tag:  'order'
  html: require '../../templates/forms/order.jade'
  parentData: null

  init: ()->
    super
    @parentData = refer {}

    @on 'update', ()=>
      if @data?
        @parentData.set 'order', @data.get()
        items = @data.get 'items'
        if !items?
          return
        for item, i in items
          @parentData.set 'order.items.' + i + '.locked', true

  isEmpty: ()->
    return @data.get('items').length == 0

  delete: (event)->
    m.trigger Events.DeleteLineItem, @data
