### //////////////////////////////////////////////////////////////////////////
#
#	TOP
#

=head1 NAME

SML::Template - Template using SIMPLIFIED MARKUP LANGUAGE

=cut

#------------------------------------------------------
# 2004/03/28 0:51 - $Date: 2004/05/13 20:06:31 $
# (C) Daniel Peder & Infoset s.r.o., all rights reserved
# http://www.infoset.com, Daniel.Peder@infoset.com
#------------------------------------------------------

###																###
###	this document is edited with tabs having only 4 chars width ###
###																###

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: package
#

	package SML::Template;


### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: version
#

	use vars qw( $VERSION $VERSION_LABEL $REVISION $REVISION_DATETIME $REVISION_LABEL $PROG_LABEL );

	$VERSION           = '0.10';
	
	$REVISION          = (qw$Revision: 1.9 $)[1];
	$REVISION_DATETIME = join(' ',(qw$Date: 2004/05/13 20:06:31 $)[1,2]);
	$REVISION_LABEL    = '$Id: Template.pm_rev 1.9 2004/05/13 20:06:31 root Exp root $';
	$VERSION_LABEL     = "$VERSION (rev. $REVISION $REVISION_DATETIME)";
	$PROG_LABEL        = __PACKAGE__." - ver. $VERSION_LABEL";

=pod

 $Revision: 1.9 $
 $Date: 2004/05/13 20:06:31 $

=cut


### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: debug
#

	use vars qw( $DEBUG ); $DEBUG=0;
	

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: constants
#

	# use constant	name		=> 'value';
	

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: modules use
#

	require 5.005_62;

	use strict                  ;
	use warnings                ;
	
	use	SML::Parser				;
	use	SML::Item				;
	

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: methods
#

=head1 METHODS

=over 4

=cut



### ##########################################################################

=item	new (  )

 $sml = SML::Template->new( );
 
=cut

### --------------------------------------------------------------------------
sub		new
### --------------------------------------------------------------------------
{
	my( $proto ) = @_;
	my	$self = bless {}, ref( $proto ) || $proto;
}


### ##########################################################################

=item	parse ( $sml )

Parse template string/sml data.

=cut

### --------------------------------------------------------------------------
sub		parse
### --------------------------------------------------------------------------
{
	my( $self, $sml )=@_;
	
		die "invalid sml data reference" if ref($sml) and ref($sml) ne 'ARRAY'; # very trivial check
	
		$self->{sml}	= SML::Parser->parse( $sml ) if !ref($sml); # string representation
		$self->{tokens_defined}	= 0;
	my	$items			= $self->{sml};
		
	#--	get template-token and template-block items
	for	my $item ( @$items )
	{

		next unless	$item->[0] eq 'E';				# skip non-element items
		next if		$item->[1];						# skip processing instructions as well as closing tags
		
		next unless	'meta' eq lc( $item->[2] );		# skip non-meta elements
		next unless	my $attr_string 	= $item->[3];	# skip if missing any attributes
		my	$attrs	= SML::Parser->parse_attributes( $attr_string );
		next unless	my	$name_attr		= $attrs->{name};
		next unless	$name_attr->[0] eq 'template';
		next unless	exists $attrs->{content};
		for my	$content_attr	( @{$attrs->{content}} )
		{
			$self->define_token( $content_attr )
		}
	}
	
	#--	hack-like post-cleanup of template definitions
	$self->define_token('token.-empty:element.replace:meta.name.template');
	$self->set_token_value( -empty => '' );
	
	return 1; 
}


### ##########################################################################

=item	define_token ( $meta_data )

Tokens are defined using structured $meta_data. 

See example lines of metadata:

to define token 'title' to feed data into any <title> element 

 $meta_data = " token.title:   element.feed:     title "
 
to define token 'title' to feed data into any <h1 ... class="my-heading" ... > element

 $meta_data = " token.title:   element.feed:     h1.class.my-heading "
 
to defined token 'text' to replace any <my-custom-element .... > element by supplied data

 $meta_data = " token.text:    element.replace:  my-custom-element "
	
=cut

### --------------------------------------------------------------------------
sub		define_token
### --------------------------------------------------------------------------
{
	my( $self, $meta_data )=@_;
	
		$meta_data		=~ s{\s+}{}gos;
	my	@token_parts	= split ':', $meta_data;
	my	$token_object	= {};
	for my $key ( qw( token method target ) )
	{
		$token_object->{$key}	= shift( @token_parts ) || '';
	}
	@$token_object{qw( token_type token_name )}											= split '\.', $token_object->{token};

	@$token_object{qw( method_target method_command method_transform )}					= split '\.', $token_object->{method};
	$token_object->{method_target}		||= 'element';
	$token_object->{method_command}		||= 'feed';
	$token_object->{method_transform}	||= 'raw';

	@$token_object{qw( target_element target_attribute target_attribute_value )}		= split '\.', $token_object->{target};
	
	push( @{ $self->{tokens_order} }, $token_object->{token_name} ) if
	( 
		!exists( $self->{token_object}{$token_object->{token_name}} )
		and substr( $token_object->{token_name}, 0, 1 ) ne '-'
	);
	
	push @{ $self->{token_object}{$token_object->{token_name}} }, $token_object;		# single token could be spread into many targets
	push @{ $self->{match_element}{$token_object->{target_element}} }, $token_object;	# link back token using element tag name
	
	$token_object->{serial_number}	=	++$self->{tokens_defined};
}


### ##########################################################################

=item	set_token_value ( $token_name, $value )

Set scalar value of named token. Doesn't check
existence of the token.

=cut

### --------------------------------------------------------------------------
sub		set_token_value
### --------------------------------------------------------------------------
{
	my( $self, $token_name, $value )=@_;
	$self->{token_value}{$token_name}	= $value;
}


### ##########################################################################

=item	get_token_value ( $token_name )

Get value currently supplied by token, 
the value could change time to time for 
previously defined any reasons.

Eg. we cold define the token to supply
current time, or fetch sequentiol values from
database. 

(However, this is one of the higher priority TODO's)

=cut

### --------------------------------------------------------------------------
sub		get_token_value
### --------------------------------------------------------------------------
{
	my( $self, $token_name )=@_;
	$self->{token_value}{$token_name}
}




### ##########################################################################

=item	build ( )

Build the whole template.

=cut

### --------------------------------------------------------------------------
sub		build
### --------------------------------------------------------------------------
{
	my( $self )=@_;

	my	$result	= '';
	my	$items	= $self->{sml};
	for	my $item ( @$items )
	{
		SML::Item->new( $item ); # bless it
		
		my	$type	= $item->[0];
		my( $pi, $name, $attrs_unparsed )	;
		my	$body							;
		my	$content						= '';
		
		if( $type eq 'E' )
		{
			( $pi, $name, $attrs_unparsed )	= @$item[1,2,3];
		}
		else	#  'C', 'T'
		{
			$body								= $item->[1];
		}
		
		check_item: 
		{
			last	unless	$type eq 'E';				# require element type items
			last	if		$pi;						# ignore processing instructions or closing tags
			last 	unless	exists $self->{match_element}{$name};
			for 	my		$token	( @{ $self->{match_element}{$name} } )
			{
				# dont disturb unless there is content to feed
				next	unless defined 
				( my	$token_value = $self->get_token_value( $token->{token_name} ));
				
				# check attributes parts if any
				if( my $target_attribute = $token->{target_attribute} )
				{
					next unless $attrs_unparsed;
					my	$item_attributes	= SML::Parser->parse_attributes( $attrs_unparsed );
					next unless exists $item_attributes->{$target_attribute};
					if( my $target_attribute_value = $token->{target_attribute_value} )
					{
						next unless	grep {$_ eq $target_attribute_value} @{ $item_attributes->{$target_attribute} };
					}
				}
				
				# so far, so good, all checks passed, let's go build result
				$type	.= '+'; # content modified
				if( 	$token->{method_target} eq 'element' )
				{
					if( 	$token->{method_command} eq 'replace' )
					{
						$content	= $token_value;
					}
					elsif(	$token->{method_command} eq 'feed' )
					{
						$content	
							=	join( '', '<', $pi, $name, $attrs_unparsed, '>' )
							.	$token_value
							;
					}
					else	# invalid: method_command
					{
						$content	
							=	join( '', '<command:', $token->{method_command}, '?', $pi, $name, $attrs_unparsed, '>' )
							.	$token_value
							;
					}
				}
				elsif( 	$token->{method_target} eq 'attribute' )
				{
					if(	$token->{method_command} eq 'set' )
					{
						$item->set_attribute_value( $token->{target_attribute}, $token_value );
						$item->build_attributes_str();
						$content	
							=	join( '', '<', $item->get_pi, $item->get_name, $item->get_attributes_str, '>' )
							;
						
					}
					else	# invalid: method_command
					{
						$content	
							=	join( '', '<command:', $token->{method_command}, '?', $pi, $name, $attrs_unparsed, '>' )
							.	$token_value
							;
					}
				}
				else	# invalid: method_target
				{
					$content	
						=	join( '', '<target:', $token->{method_target}, '?', $pi, $name, $attrs_unparsed, '>' )
						.	$token_value
						;
				}
				last check_item if 0; # 0=css effect, 1=first match
			}
		}
		
		if(		$type eq 'E' )	# restore element
		{
			$result	.= join( '', '<', $pi, $name, $attrs_unparsed, '>' );
		}
		elsif(	$type eq 'C' )	# restore comment
		{
			$result	.= join( '', '<!--', $body, '-->' );
		}
		elsif(	$type eq 'T' )	# restore text
		{
			$result	.= $body;
		}
		else
		{
			$result	.= $content;
		}
	}
	$result
}


### ##########################################################################

=item	get_tokens_definition_order ( )

Return names of tokens as they first appeared in definition list.

=cut

### --------------------------------------------------------------------------
sub		get_tokens_definition_order
### --------------------------------------------------------------------------
{
	my( $self )=@_;
	
	wantarray ? @{$self->{tokens_order}} : $self->{tokens_order}

}


### ##########################################################################

=item	build_sml_input_form ( )

Build simple input form suitable for tex/plain editing and feeding trough SML::Block.

=cut

### --------------------------------------------------------------------------
sub		build_sml_input_form
### --------------------------------------------------------------------------
{
	my( $self )=@_;
	
	my	$form	= '';
	for my $token_name ( $self->get_tokens_definition_order )
	{
		$form	.= "<!section $token_name>\n\n\n";
	}
	$form
}






=back

=cut


1;

__DATA__

__END__

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: TODO
#

=head1 TODO	

- substitution into element attributes

- rewrite some parts of code into methods and subclasses

=cut
