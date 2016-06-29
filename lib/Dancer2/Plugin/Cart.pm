package Dancer2::Plugin::Cart;
use strict;
use warnings;
use Dancer2::Plugin;
use Dancer2::Plugin::Cart::InlineViews;
use JSON;
our $VERSION = '0.0001';  #Version

BEGIN{
  has 'product_list' => (
    is => 'ro',
    from_config => 1,
    default => sub { [] }
  );

  has 'products_view_template' => (
    is => 'ro',
    from_config => 'views.products',
    default => sub {}
  );

  has 'cart_view_template' => (
    is => 'ro',
    from_config => 'views.products',
    default => sub {}
  );

  has 'cart_receipt_template' => (
    is => 'ro',
    from_config => 'views.receipt',
    default => sub {}
  );

  has 'cart_checkout_template' => (
    is => 'ro',
    from_config => 'views.checkout',
    default => sub {}
  );

  has 'shipping_view_template' => (
    is => 'ro',
    from_config => 'views.shipping',
    default => sub {}
  );

  has 'billing_view_template' => (
    is => 'ro',
    from_config => 'views.billing',
    default => sub {}
  );

  has 'review_view_template' => (
    is => 'ro',
    from_config => 'views.review',
    default => sub {}
  );

  has 'receipt_view_template' => (
    is => 'ro',
    from_config => 'views.receipt',
    default => sub {}
  );

  has 'default_routes' => (
    is => 'ro',
    from_config => 1,
    default => sub { '1' }
  );

  has 'excluded_routes' => (
    is => 'ro',
    from_config => 1,
    default => sub { [] }
  );

  plugin_keywords qw/ 
    products
    cart
    cart_add
    cart_add_item
    clear_cart
    subtotal
    billing
    shipping
    checkout
    close_cart
    adjustments
  /;

  plugin_hooks qw/
		products
    before_cart
    after_cart
    validate_cart_add_params
    before_cart_add
    after_cart_add
    before_cart_add_item
    after_cart_add_item
    validate_shipping_params
    before_shipping
    after_shipping
    validate_billing_params
    before_billing
    after_billing
    validate_checkout_params
    before_checkout
    checkout
    after_checkout
    before_close_cart
    after_close_cart
    before_clear_cart
    after_clear_cart
    before_subtotal
    after_subtotal
    adjustments
  /;
}

sub BUILD {
  my $self = shift;
  #Create a session 
  my $settings = $self->app->config;
  my $excluded_routes = $self->excluded_routes;

  if( $self->default_routes ){  
    $self->app->add_route(
      method => 'get',
      regexp => '/products',
      code   => sub { 
        my $app = shift;
        #generate session if didn't exists
        $app->session;
        my $template = $self->products_view_template || '/products.tt' ;
        if( -e $self->app->config->{views}.$template ) {
          $app->template( $template, {
            product_list => $self->product_list
          },
					{
						layout => 'cart.tt'
					});
        }
        else{
          _products_view({ product_list => $self->product_list });
        }
      },
    )if !grep { $_ eq 'products' }@{$excluded_routes};

    $self->app->add_route(
      method => 'get',
      regexp => '/cart',
      code => sub {
        my $app = shift;
        my $cart = $self->cart;
        #Generate session if didn't exists
        $app->session;
        my $template = $self->cart_view_template || '/cart/cart.tt' ;
        my $page = "";
        if( -e $self->app->config->{views}.$template ) {
          $page = $app->template(  $template, {
            ec_cart => $app->session->read('ec_cart'),
          } );
        }
        else{
           $page = _cart_view({ ec_cart => $app->session->read('ec_cart') });
        }
        my $ec_cart = $app->session->read('ec_cart');
        delete $ec_cart->{add}->{error} if $ec_cart->{add}->{error};
        $app->session->write( 'ec_cart', $ec_cart );
        $page;
      }
    )if !grep { $_ eq 'cart' }@{$excluded_routes};

    $self->app->add_route(
      method => 'post',
      regexp => '/cart/add',
      code => sub {
        my $app = shift;
        $self->cart_add;
        $app->redirect('/cart');
      }
    )if !grep { $_ eq 'cart/add' }@{$excluded_routes};


    $self->app->add_route(
      method => 'get',
      regexp => '/cart/clear',
      code => sub {
        my $app = shift;
        $self->clear_cart;
        $app->redirect('/cart');
      } 
    )if !grep { $_ eq 'cart/clear' }@{$excluded_routes};

    $self->app->add_route(
      method => 'get',
      regexp => '/cart/shipping',
      code => sub {
        my $app = shift;
        my $cart = $self->cart;
        my $template = $self->shipping_view_template || '/cart/shipping.tt';
        my $page = "";
        if( -e $app->config->{views}.$template ) {
            $page = $app->template ($template, {
            ec_cart => $app->session->read('ec_cart'),
          });
        }
        else{
          $page = _shipping_view({ ec_cart => $app->session->read('ec_cart') });
        }
        my $ec_cart = $app->session->read('ec_cart');
        delete $ec_cart->{shipping}->{error} if $ec_cart->{shipping}->{error};
        $app->session->write( 'ec_cart', $ec_cart );
        $page;
      }
    )if !grep { $_ eq 'cart/shipping' }@{$excluded_routes}; 
  
    $self->app->add_route(
      method => 'post',
      regexp => '/cart/shipping',
      code => sub {
        my $app = shift;
        $self->shipping;
        $app->redirect('/cart/billing');
      }
    )if !grep { $_ eq 'cart/shipping' }@{$excluded_routes}; 

    $self->app->add_route(
      method => 'get',
      regexp => '/cart/billing',
      code => sub {
        my $app = shift;
        my $cart = $self->cart;
        my $template = $self->billing_view_template || '/cart/billing.tt' ;
        my $page = "";
        if( -e $app->config->{views}.$template ) {
            $page = $app->template( $template, {
            ec_cart => $app->session->read('ec_cart'),
          });
        }
        else{
          $page = _billing_view({ ec_cart => $app->session->read('ec_cart') });
        }
        my $ec_cart = $app->session->read('ec_cart');
        delete $ec_cart->{billing}->{error} if $ec_cart->{billing}->{error};
        $app->session->write( 'ec_cart', $ec_cart );
        $page;
      }
    )if !grep { $_ eq 'cart/billing' }@{$excluded_routes}; 

    $self->app->add_route(
      method => 'post',
      regexp => '/cart/billing',
      code => sub {
        my $app = shift;
        $self->billing; 
        $app->redirect('/cart/review');
      }
    )if !grep { $_ eq 'cart/billing' }@{$excluded_routes}; 
    
    $self->app->add_route(
      method => 'get',
      regexp => '/cart/review',
      code => sub { 
        my $app = shift;
        my $cart = $self->cart;
        my $page = "";
        my $template = $self->review_view_template || '/cart/review.tt' ;
        if( -e $app->config->{views}.$template ) {
            $page = $app->template($template,{
              ec_cart => $app->session->read('ec_cart'),
            });
        }
        else{
          $page = _review_view( { cart => $cart , ec_cart => $app->session->read('ec_cart') } );
        }
        my $ec_cart = $app->session->read('ec_cart');
        delete $ec_cart->{checkout}->{error} if $ec_cart->{checkout}->{error};
        $app->session->write('ec_cart',$ec_cart);
        $page;
      }
    )if !grep { $_ eq 'cart/review' }@{$excluded_routes}; 

    $self->app->add_route(
      method => 'post',
      regexp => '/cart/checkout',
      code => sub {
        my $app = shift;
        $self->checkout;
        $app->redirect('/cart/receipt');
      }
    )if !grep { $_ eq 'cart/receipt' }@{$excluded_routes}; 

    $self->app->add_route(
      method => 'get',
      regexp => '/cart/receipt',
      code => sub {
        my $app = shift;
        my $template = $self->receipt_view_template || '/cart/receipt.tt' ;
        my $page = "";
				my $ec_cart = $app->session->read('ec_cart');
        if( -e $app->config->{views}.$template ) {
            $page = $app->template($template, { cart => $ec_cart } );
        }
        else{
          $page = _receipt_view({ ec_cart => $ec_cart });
        }
        $app->session->delete('ec_cart');
        $page;
      }
    )if !grep { $_ eq 'cart/receipt' }@{$excluded_routes}; 
  }
};


sub products {
  my ( $self ) = @_;
  my $app = $self->app;
	my $ec_cart = $self->cart;
	if ( $self->product_list ){
		 $ec_cart->{products} = $self->product_list;
	}
 	$app->session->write( 'ec_cart', $ec_cart );
  $app->execute_hook('plugin.cart.products');
	return $ec_cart->{products};
}

sub cart_add_item {
  my ( $self, $product ) = @_;
  my $app = $self->app;
	my $index = 0;
	my $ec_cart = $self->cart; 
	$ec_cart->{cart}->{items} = [] unless $ec_cart->{cart}->{items};
	foreach my $cart_product ( @{$ec_cart->{cart}->{items}} ){
    if( $cart_product->{ec_sku} eq $product->{ec_sku} ){
			$cart_product->{ec_quantity} += $product->{ec_quantity};
			$cart_product->{ec_subtotal} = $cart_product->{ec_quantity} * $cart_product->{ec_price};
			if(  $cart_product->{ec_quantity} <= 0 ){
			  splice @{$ec_cart->{cart}->{items}}, $index, 1;
			}
  		$app->session->write( 'ec_cart', $ec_cart );
			return $cart_product;
    }
		$index++;
  }
	
  foreach my $product_item ( @{$self->products} ){
		if( $product_item->{ec_sku} eq $product->{ec_sku} ){
			$product->{ec_price} = $product_item->{ec_price} * $product->{ec_quantity};
			$product->{ec_subtotal} = $product->{ec_price};
		}
	}
	push @{$ec_cart->{cart}->{items}}, $product;
  $app->session->write( 'ec_cart', $ec_cart );
	
	return $product;
};

sub cart {
  my ( $self ) = @_;
  my $app = $self->app;
  $app->execute_hook('plugin.cart.before_cart');
  my $ec_cart = $app->session->read('ec_cart');
	$ec_cart->{cart}->{items} = [] unless $ec_cart->{cart}->{items};
	$app->session->write('ec_cart', $ec_cart);
	$self->subtotal;
  $self->adjustments;
  $self->total;
  $ec_cart = $app->session->read('ec_cart');
  $app->execute_hook('plugin.cart.after_cart');
  $ec_cart = $app->session->read('ec_cart');
  return $ec_cart;
};


sub subtotal{
  my ($self, $params) = @_;
  my $app = $self->app;

  $self->execute_hook ('plugin.cart.before_subtotal');
  my $ec_cart = $app->session->read('ec_cart');
  my $subtotal = 0;
  foreach my $item_subtotal ( @{ $ec_cart->{cart}->{items} } ){
    $subtotal += $item_subtotal->{ec_subtotal} if $item_subtotal->{ec_subtotal};
  }
  $ec_cart->{cart}->{subtotal} = $subtotal;
  $app->session->write('ec_cart',$ec_cart);
  $self->execute_hook ('plugin.cart.after_subtotal');
  $ec_cart = $app->session->read('ec_cart');
  $ec_cart->{cart}->{subtotal};
}


sub clear_cart {
  my ($self, $params ) = @_;
  $self->execute_hook ('plugin.cart.before_clear_cart');
  $self->app->session->delete('ec_cart');
  $self->execute_hook ('plugin.cart.after_clear_cart');
}


sub cart_add {
  my ($self, $params) = @_;

  my $app = $self->app;
  my $form_params = { $app->request->params };
  my $product = undef;
  
  #Add params to ec_cart session
  my $ec_cart = $app->session->read( 'ec_cart' );
  $ec_cart->{add}->{form} = $form_params; 
  $app->session->write( 'ec_cart', $ec_cart );

  #Param validation
  $app->execute_hook( 'plugin.cart.validate_cart_add_params' );
  $ec_cart = $app->session->read('ec_cart');
  
  if ( $ec_cart->{add}->{error} ){
    $self->app->redirect( $app->request->referer || $app->request->uri  );
  }
  else{
    #Cart operations before add product to the cart.
    $app->execute_hook( 'plugin.cart.before_cart_add' );
    $ec_cart = $app->session->read('ec_cart');

    if ( $ec_cart->{add}->{error} ){
      $self->app->redirect( $app->request->referer || $app->request->uri  );
    }
    else{
      $app->execute_hook( 'plugin.cart.before_cart_add_item' );
      $product = $self->cart_add_item({
          ec_sku => $ec_cart->{add}->{form}->{'ec_sku'},
          ec_quantity => $ec_cart->{add}->{form}->{'ec_quantity'},
        }
      );
      $app->execute_hook( 'plugin.cart.after_cart_add_item' );

      #Cart operations after adding product to the cart
      $app->execute_hook( 'plugin.cart.after_cart_add' );
      $ec_cart = $app->session->read('ec_cart');
      delete $ec_cart->{add};
      $app->session->write( 'ec_cart', $ec_cart );
    }
  }
}

sub shipping {
  my $self = shift;
  my $app = $self->app;
  my $params = { $app->request->params };
  #Add params to ec_cart session
  my $ec_cart = $app->session->read( 'ec_cart' );
  $ec_cart->{shipping}->{form} = $params; 
  $app->session->write( 'ec_cart', $ec_cart );
  $app->execute_hook( 'plugin.cart.validate_shipping_params' );
  $ec_cart = $app->session->read('ec_cart');
  if ( $ec_cart->{shipping}->{error} ){ 
    $app->redirect( $app->request->referer || $app->request->uri );
  }
  else{
    $app->execute_hook( 'plugin.cart.before_shipping' );
    my $ec_cart = $app->session->read('ec_cart');

    if ( $ec_cart->{shipping}->{error} ){
      
      $app->redirect( ''.$app->request->referer || $app->request->uri  );
    }
    $app->execute_hook( 'plugin.cart.after_shipping' );
  }
}

sub billing{
  my $self = shift;
  my $app = $self->app;
  my $params = { $app->request->params };
  #Add params to ec_cart session
  my $ec_cart = $app->session->read( 'ec_cart' );
  $ec_cart->{billing}->{form} = $params; 
  $app->session->write( 'ec_cart', $ec_cart );
  $app->execute_hook( 'plugin.cart.validate_billing_params' );
  $ec_cart = $app->session->read('ec_cart');
  if ( $ec_cart->{billing}->{error} ){
    $app->redirect( $app->request->referer || $app->request->uri );
  }
  else{
    $app->execute_hook( 'plugin.cart.before_billing' );
    my $ec_cart = $app->session->read('ec_cart');

    if ( $ec_cart->{billing}->{error} ){
      $app->redirect( $app->request->referer || $app->request->uri  );
    }
    $app->execute_hook( 'plugin.cart.after_billing' );
  }
}

sub checkout{
  my $self = shift;
  my $app = $self->app;

  my $params = ($app->request->params);
  $app->execute_hook( 'plugin.cart.validate_checkout_params' );
  my $ec_cart = $app->session->read('ec_cart');

  if ( $ec_cart->{checkout}->{error} ){
    $app->redirect( $app->request->referer || $app->request->uri  );
  }
  else{
    $app->execute_hook( 'plugin.cart.checkout' ); 
    $ec_cart = $app->session->read('ec_cart');
    if ( $ec_cart->{checkout}->{error} ){
      $app->redirect( $app->request->referer || $app->request->uri  );
    }
    $self->close_cart;
    $app->execute_hook( 'plugin.cart.after_checkout' );
  }
}

sub close_cart{
  my ($self, $params) = @_;
  my $app = $self->app;
  my $ec_cart = $self->cart;
  return { error => 'Cart without items' } unless @{$ec_cart->{cart}->{items}} > 0;
  $app->execute_hook( 'plugin.cart.before_close_cart' ); 
	$ec_cart->{cart}->{session} = $app->session->id;
	$ec_cart->{cart}->{status} = 1;
  $app->session->write('ec_cart', $ec_cart );
  $app->execute_hook( 'plugin.cart.after_close_cart' ); 
}

sub adjustments {
  my ($self, $params) = @_;
  my $app = $self->app;
  my $ec_cart = $app->session->read('ec_cart');
  my $default_adjustments = [
    {
      description => 'Discounts',
      value => '0'
    },
    {
      description => 'Shipping',
      value => '0'
    },
    {
      description => 'Taxes',
      value => '0'
    },
  ];
  $ec_cart->{cart}->{adjustments} = $default_adjustments;
  $app->session->write( 'ec_cart', $ec_cart );
  $app->execute_hook('plugin.cart.adjustments');
}


sub total {
  my ($self) = shift;
  my $app = $self->app;
  my $total = 0;
  my $ec_cart = $app->session->read('ec_cart');
  $total += $ec_cart->{cart}->{subtotal};
  foreach my $adjustment ( @{$ec_cart->{cart}->{adjustments}}){
    $total += $adjustment->{value};
  }
  $ec_cart->{cart}->{total} = $total;
  $app->session->write('ec_cart', $ec_cart );
  return $total;
}


1;
__END__
