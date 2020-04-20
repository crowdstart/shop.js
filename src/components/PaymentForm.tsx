import React, { useMemo } from 'react'
import classnames from 'classnames'

import {
  MUIText,
} from '@hanzo/react'

import { useTheme } from '@material-ui/core/styles'

import { useMidstream } from '../hooks'

import {
  isRequired,
} from '@hanzo/middleware'

import {
  Box,
  Button,
  Grid,
  InputAdornment,
  Typography,
  TextField,
} from '@material-ui/core'

import LockIcon from '@material-ui/icons/Lock';

import usePaymentInputs from 'react-payment-inputs/es/usePaymentInputs';
import images from 'react-payment-inputs/images';

import { makeStyles } from '@material-ui/core/styles'

const useStyles = makeStyles((theme) => ({
  form: {
    paddingTop: theme.spacing(2),
    paddingBottom: theme.spacing(2),
  },
}))

const PaymentForm = ({
  width,
  height,
  payment,
  setPayment,
  setFormAwait,
  checkout,
  back,
  next,
  termsUrl,
  isActive,
  isLoading,
  paymentIcon,
  paymentTitle,
}): JSX.Element => {
  const classes = useStyles()

  const {
    meta,
    getCardImageProps,
    getCardNumberProps,
    getExpiryDateProps,
    getCVCProps,
  } = usePaymentInputs()
  const { erroredInputs, touchedInputs } = meta

  const {
    setName,
    setNumber,
    setCvc,
    setMonth,
    setYear,
    setTerms,
    err,
    run,
  } = useMidstream({
    name: [isRequired],
    number: [isRequired],
    cvc: [isRequired],
    month: [isRequired],
    year: [isRequired],
  }, {
    dst: (k, v) => {
      if (k == 'terms') {
        return
      }

      setPayment(k, v)
    },
  })

  let {
    ...cardNumberProps
  } = getCardNumberProps({
    onBlur: (e) => {
      setNumber(e.target.value)
    },
    onChange: (e) => {
      setNumber(e.target.value)
    },
  })

  let cardNumberPropsRef = cardNumberProps.ref
  delete cardNumberProps.ref

  let {
    ...cvcProps
  } = getCVCProps({
    onBlur: (e) => {
      setCvc(e.target.value)
    },
    onChange: (e) => {
      setCvc(e.target.value)
    },
  })

  let cvcPropsRef = cvcProps.ref
  delete cvcProps.ref

  let {
    ...expiryDateProps
  } = getExpiryDateProps({
    onBlur: (e) => {
      let v = e.target.value ?? ''
      let [month, year] = v.replace(/\s+/g, '').split('/')
      setMonth(`${parseInt(month, 10)}`)
      setYear(`20${year}`)
    },
    onChange: (e) => {
      let v = e.target.value ?? ''
      let [month, year] = v.replace(/\s+/g, '').split('/')
      setMonth(`${parseInt(month, 10)}`)
      setYear(`20${year}`)
    },
  })

  let expiryDatePropsRef = expiryDateProps.ref
  delete expiryDateProps.ref

  const submit = useMemo(() => async () => {
    let ret = await run()

    if (ret instanceof Error) {
      console.log('payment form error', ret)
      throw ret
    }
  }, [])

  if (isActive) {
    requestAnimationFrame(() => {
      setFormAwait(submit)
    })
  }

  return (
    <div className='payment'>
      <Grid container>
        <Grid item xs={12} className='payment-header'>
          <Grid container spacing={1} alignItems='center'>
            <Grid item className='payment-icon'>
              { paymentIcon || <LockIcon style={{fontSize: '2rem'}}/> }
            </Grid>
            <Grid item className='payment-title'>
              { paymentTitle || (
                <Typography variant='h6'>
                  Payment Information
                </Typography>
              )}
            </Grid>
          </Grid>
        </Grid>
      </Grid>

      <Grid container className={classnames(classes.form, 'payment-body')} spacing={3}>
        <Grid item xs={12} className='payment-card-name'>
          <MUIText
            fullWidth
            label='Name on Card'
            variant={undefined}
            size='medium'
            value={payment.name}
            setValue={setName}
            error={err.name}
          />
        </Grid>

        <Grid item xs={12} className='payment-card-numbers'>
          <TextField
            { ...cardNumberProps }
            inputRef={ cardNumberPropsRef }
            fullWidth
            label='Number'
            placeholder='0000 0000 0000 0000'
            size='medium'
            error={touchedInputs.cardNumber && erroredInputs.cardNumber || err.number}
            helperText={touchedInputs.cardNumber && erroredInputs.cardNumber || err.number && err.number.message}
            InputProps={{
              startAdornment: (
                <InputAdornment position='start'>
                  <svg {...getCardImageProps({ images })} />
                </InputAdornment>
              ),
            }}
          />
        </Grid>

        <Grid item xs={6} className='payment-card-expiry'>
          <TextField
            { ...expiryDateProps }
            inputRef={ expiryDatePropsRef }
            fullWidth
            label='Expiry Date'
            placeholder='MM/YY'
            size='medium'
            error={touchedInputs.expiryDate && erroredInputs.expiryDate || err.month || err.year}
            helperText={touchedInputs.expiryDate && erroredInputs.expiryDate || err.month && err.month.message || err.year && err.year.message}
          />
        </Grid>

        <Grid item xs={6} className='payment-card-cvc'>
          <TextField
            { ...cvcProps }
            inputRef={ cvcPropsRef }
            fullWidth
            label='CVC'
            placeholder='123'
            size='medium'
            error={touchedInputs.cvc && erroredInputs.cvc || err.cvc}
            helperText={touchedInputs.cvc && erroredInputs.cvc || err.cvc && err.cvc.message}
          />
        </Grid>
      </Grid>
    </div>
  )
}

export default PaymentForm
