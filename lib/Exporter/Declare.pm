package Exporter::Declare;
use strict;
use warnings;

use Carp qw/croak/;
use Devel::Declare::Parser::Sublike;
use Scalar::Util qw/reftype/;
use aliased 'Exporter::Declare::Meta';
use aliased 'Exporter::Declare::Specs';
use aliased 'Exporter::Declare::Export::Sub';
use aliased 'Exporter::Declare::Export::Variable';
use aliased 'Exporter::Declare::Export::Generator';

BEGIN { Meta->new( __PACKAGE__ )}

our $VERSION = '0.100';

default_exports( qw/
    import
    exports
    default_exports
    import_options
    import_arguments
    export_tag
/);

exports( qw/
    parsed_exports
    parsed_default_exports
    reexport
    export_to
/);

parsed_exports( export => qw/
    export
    gen_export
    default_export
    gen_default_export
    parser
/);

export_tag( magic => qw/
    -default
    export
    gen_export
    default_export
    gen_default_export
    parser
    parsed_exports
    parsed_default_exports
/);

sub import {
    my $class = shift;
    my $caller = caller;
    my $specs = export_to( $class, $caller, @_ );
    $class->after_import( $caller, $specs )
        if $class->can( 'after_import' );
}

sub after_import {
    my $class = shift;
    my ( $caller, $specs ) = @_;
    Meta->new( $caller );
}

sub export_to {
    my $class = _find_export_class( \@_ );
    my ( $dest, @args ) = @_;
    my $specs = Specs->new( $class, @args );
    $specs->export( $dest );
    return $specs;
}

sub export_tag {
    my $class = _find_export_class( \@_ );
    my ( $tag, @list ) = @_;
    $class->export_meta->push_tag( $tag, @list );
}

sub exports {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    _export( $class, undef, $_ ) for @_;
    $meta->get_tag('all');
}

sub default_exports {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    $meta->push_tag( 'default', _export( $class, undef, $_ ))
        for @_;
    $meta->get_tag('default');
}

sub parsed_exports {
    my $class = _find_export_class( \@_ );
    my ( $parser, @items ) = @_;
    croak "no parser specified" unless $parser;
    export( $class, $_, $parser ) for @items;
}

sub parsed_default_exports {
    my $class = _find_export_class( \@_ );
    my ( $parser, @names ) = @_;
    croak "no parser specified" unless $parser;
    default_export( $class, $_, $parser ) for @names;
}

sub export {
    my $class = _find_export_class( \@_ );
    _export( $class, undef, @_ );
}

sub gen_export {
    my $class = _find_export_class( \@_ );
    _export( $class, Generator(), @_ );
}

sub default_export {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    $meta->push_tag( 'default', _export( $class, undef, @_ ));
}

sub gen_default_export {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    $meta->push_tag( 'default', _export( $class, Generator(), @_ ));
}

sub parser {
    my $class = _find_export_class( \@_ );
    my $name = shift;
    my $code = pop;
    croak "You must provide a name to parser()"
        if !$name || ref $name;
    croak "Too many parameters passed to parser()"
        if @_ && defined $_[0];
    $code ||= $class->can( $name );
    croak "Could not find code for parser '$name'"
        unless $code;

    $class->export_meta->_parsers->{ $name } = $code;
}

sub import_options {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    $meta->add_options(@_) if @_;
}

sub import_arguments {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    $meta->add_arguments(@_) if @_;
}

sub _export {
    my ( $class, $expclass, $name, @param ) = @_;
    my $ref = ref($param[-1]) ? pop(@param) : undef;
    my ( $parser ) = @param;
    my $meta = $class->export_meta;

    ( $ref, $name ) = $meta->get_ref_from_package( $name )
        unless $ref;

    ( my $type, $name ) = ($name =~ m/^([\$\@\&\%]?)(.*)$/);
    $type = "" if $type eq '&';

    my $fullname = "$type$name";

    $expclass ||= reftype( $ref ) eq 'CODE'
        ? Sub()
        : Variable();

    $expclass->new(
        $ref,
        exported_by => $class,
        ($parser ? ( parser => $parser    )
                 : (                      )),
        ($type   ? ( type   => 'variable' )
                 : ( type   => 'sub'      )),
    );

    $meta->add_export( $fullname, $ref );

    return $fullname;
}

sub _find_export_class {
    my $args = shift;

    return shift( @$args )
        if @$args
        && eval { $args->[0]->can('export_meta') };

    return caller(1);
}

sub reexport {
    my $from = pop;
    my $class = shift || caller;
    $class->export_meta->reexport( $from );
}

1;

=head1 NAME

Exporter::Declare - Declarative exporting, better import interface.

=head1 DESCRIPTION

Exporter::Declare is a declarative exporting tool that uses a meta data object
to track exports on a per-object basis. It also provides tools to create a
parameterized input() method so that you are not forced to wrap a black-box
import() method.

Exporting tools can be frustrating, L<Exporter> is showing its age.
L<Sub::Exporter> is a bit complicated for the module doing the exporting. Above
all else most export modules install their own import() function that can be a
pain to wrap or override without screwing something up.

Exporter declare solves these problems and more by providing the following:

=over 4

=item Declarative Exporting (Like L<Moose> for Exporting)

=item Meta Class Instead of Package Variables

=item Hooks Into import()

=item Support For Export Groups (tags)

=item Export Generators (Subs And Variables)

=item Higher Level Interface To L<Devel::Declare>

=item Clear And Concise OO API

=item All Exports Are Blessed

=item Extended Import Syntax Based On L<Sub::Exporter>

=item The '-alias' Tag Can Be Used On Any Exporter To Generate An Alias

=back

=head1 SYNOPSIS

=head2 EXPORTER

    package Some::Exporter;
    use Exporter::Declare;

    default_exports qw/ do_the_thing /;
    exports qw/ subA subB $SCALAR @ARRAY %HASH /;

    export_tag subs => qw/ subA subB do_the_thing /;
    export_tag vars => qw/ $SCALAR @ARRAY %HASH /;

    import_options   qw/ optionA optionB /;
    import_arguments qw/ optionC optionD /;

    # No need to fiddle with import() or do any wrapping.
    # No need to parse the arguments yourself!

    sub after_import {
        my $class = shift;
        my ( $importer, $specs ) = @_;

        do_option_a() if $specs->config->{optionA}

        do_option_c( $specs->config->{optionC} )
            if $specs->config->{optionC}

        print "-subs tag was used\n"
            if $specs->config->{subs};

        print "exported 'subA'\n"
            if $specs->exports->{subA};
    }

    ...

=head2 IMPORTER

    package Some::Importer;
    use Some::Exporter qw/ subA $SCALAR !%HASH /,
                        -default => { -prefix => 'my_' },
                        qw/ -optionA !-optionB /,
                        subB => { -as => 'sub_b' };

    subA();
    print $SCALAR;
    sub_b();
    my_do_the_thing();

    ...

=head2 ADVANCED EXPORTER

    package Some::Exporter;
    use Exporter::Declare qw/-magic reexport export_to /;

    ... #Same as the basic exporter synopsis

    Quoting is not necessary unless you have space or special characters
    export another_sub;
    export parsed_sub parser;

    # no 'sub' keyword, not a typo
    export anonymous_export {
        ...
    }
    #No semicolon, not a typo

    export parsed_anon parser {
        ...
    }

    # Same as export
    default_export name { ... }

    export $VAR;
    export %VAR;

    # $ref can be a ref to code, hash, array, or scalar.
    export name => $ref;

    my $iterator = 'a';
    gen_export unique_class_id {
        my $current = $iterator++;
        return sub { $current };
    }

    gen_default_export '$my_letter' {
        my $letter = $iterator++;
        return \$letter;
    }

    parser myparser {
        ... See Devel::Declare
    }

    parsed_exports parser => qw/ parsed_sub_a parsed_sub_b /;
    parsed_default_exports parser_b => qw/ parsed_sub_c /;

    # Can re-export other Exporter::Declare exports, or even Exporter.pm based exports
    reexport 'Another::Exporter';

    export_to( $some_class, @args );

=head1 IMPORT INTERFACE

Importing from a package that uses Exporter::Declare will be familiar to anyone
who has imported from modules before. Arguments are all assumed to be export
names, unless prefixed with C<-> or C<:> In which case they may be a tag or an
option. Exports without a sigil are assumed to be code exports, variable
exports must be listed with their sigil.

Items prefixed with the C<!> symbol are forcfully excluded, regardless of any
listed item that may normally include them. Tags can also be excluded, this
will effectively exclude everything in the tag.

Tags are simply lists of exports, the exporting class may define any number of
tags. Exporter::Declare also has the concept of options, they have the same
syntax as tags. Options may be boolean or argument based. Boolean options are
actually 3 value, undef, false C<!>, or true. Argument based options will grab
the next value in the arguments list as their own, regardless of what type of
value it is.

When you use the module, or call import(), all the arguments are transformed
into an L<Exporter::Declare::Specs> object. Arguments are parsed for you into a
list of imports, and a configuration hash in which tags/options are keys. Tags
are listed in the config hash as true, false, or undef depending on if they
were included, negated, or unlisted. Boolean options will be treated in the
same way as tags. Options that take arguments will have the argument as their
value.

=head2 SELECTING ITEMS TO IMPORT

Exports can be subs, or package variables (scalar, hash, array). For subs
simply ask for the sub by name, you may optionally prefix the subs name with
the sub sigil C<&>. For variables list the variable name along with its sigil
C<$, %, or @>.

    use Some::Exporter qw/ somesub $somescalar %somehash @somearray /;

=head2 TAGS

Every exporter automatically has the following 3 tags, in addition they may
define any number of custom tags. Tags can be specified by their name prefixed
by either C<-> or C<:>.

=over 4

=item -all

This tag may be used to import everything the exporter provides.

=item -default

This tag is used to import the default items exported. This will be used when
no argument is provided to import.

=item -alias

Every package has an alias that it can export. This is the last segmant of the
packages namespace. IE C<My::Long::Package::Name::Foo> could export the C<Foo()>
function. These alias functionis simply return the full package name as a
string, in this case C<'My::Long::Package::Name::Foo'>. This is similar to
L<aliased>.

The -alias tag is a shortcut so that you do not need to think about what the
alias name would be when adding it to the import arguments.

    use My::Long::Package::Name::Foo -alias;

    my $foo = Foo()->new(...);

=back

=head2 RENAMING IMPORTED ITEMS

You can prefix, suffix, or completely rename the items you import. Whenever an
item is followed by a hash in the import list, that hash will be used for
configuration. Configuration items always start with a dash C<->.

The 3 available configuration options that effect import names are C<-prefix>,
C<-suffix>, and C<-as>. If C<-as> is seen it will be used as is. If prefix or
suffix are seen they will be attached to the original name (unless -as is
present in which case they are ignored).

    use Some::Exporter subA => { -as => 'DoThing' },
                       subB => { -prefix => 'my_', -suffix => '_ok' };

The example above will import C<subA()> under the name C<DoThing()>. It will
also import C<subB()> under the name C<my_subB_ok()>.

You may als specify a prefix and/or suffix for tags. The following example will
import all the default exports with 'my_' prefixed to each name.

    use Some::Exporter -default => { -prefix => 'my_' };

=head2 OPTIONS

Some exporters will recognise options. Options look just like tags, and are
specified the same way. What options do, and how they effect things is
exporter-dependant.

    use Some::Exporter qw/ -optionA -optionB /;

=head2 ARGUMENTS

Some options require an argument. These options are just like other
tags/options except that the next item in the argument list is slurped in as
the option value.

    use Some::Exporter -ArgOption    => 'Value, not an export',
                       -ArgTakesHash => { ... };

Once again available options are exporter specific.

=head2 PROVIDING ARGUMENTS FOR GENERATED ITEMS

Some items are generated at import time. These items may accept arguments.
There are 3 ways to provide arguments, and they may all be mixed (though that
is not recommended).

As a hash

    use Some::Exporter generated => { key => 'val', ... };

As an array

    use Some::Exporter generated => [ 'Arg1', 'Arg2', ... ];

As an array in a config hash

    use Some::Exporter generated => { -as => 'my_gen', -args => [ 'arg1', ... ]};

You can use all three at once, but this is really a bad idea, documented for completeness:

    use Some::Exporter generated => { -as => 'my_gen, key => 'value', -args => [ 'arg1', 'arg2' ]}
                       generated => [ 'arg3', 'arg4' ];

The example above will work fine, all the arguments will make it into the
generator. The only valid reason for this to work is that you may provide
arguments such as C<-prefix> to a tag that brings in generator(), while also
desiring to give arguments to generator() independantly.

=head1 PRIMARY EXPORT API

With the exception of import(), all the following work equally well as
functions or class methods.

=over 4

=item import( @args )

The import() class method. This turns the @args list into an
L<Exporter::Declare::Specs> object.

=item exports( @add_items )

Add items to be exported.

=item @list = exports()

Retrieve list of exports.

=item default_exports( @add_items )

Add items to be exported, and add them to the -default tag.

=item @list = default_exports()

List of exports in the -default tag

=item import_options(@add_items)

Specify boolean options that should be accepted at import time.

=item import_arguments(@add_items)

Specify options that should be accepted at import that take arguments.

=item export_tag( $name, @add_items );

Define an export tag, or add items to an existing tag.

=back

=head1 EXTENDED EXPORT API

These all work fine in function or method form, however the syntax sugar will
only work in function form.

=over 4

=item parsed_exports( $parser, @exports )

Add exports that should use a 'Devel::Declare' based parser. The parser should
be the name of a registered L<Devel::Declare::Interface> parser, or the name of
a parser sub created using the parser() function.

=item parsed_default_exports( $parser, @exports )

Same as parsed_exports(), except exports are added to the -default tag.

=item parser name { ... }

=item parser name => \&code

Define a parser. You need to be familiar with Devel::Declare to make use of
this.

=item reexport( $package )

Make this exporter inherit all the exports and tags of $package. Works for
Exporter::Declare or Exporter.pm based exporters. Re-Exporting of
L<Sub::Exporter> based classes is not currently supported.

=item export_to( $package, @args )

Export to the specified class.

=item export( $name )

=item export( $name, $ref )

=item export( $name, $parser )

=item export( $name, $parser, $ref )

=item export name { ... }

=item export name parser { ... }

export is a keyword that lets you export any 1 item at a time. The item can be
exported by name, name+ref, or name+parser+ref. You can also use it without
parentheses or quotes followed by a codeblock. In the codeblock form the export
is created, but there is no corresponding variable/sub in the packages
namespace.

=item default_export( $name )

=item default_export( $name, $ref )

=item default_export( $name, $parser )

=item default_export( $name, $parser, $ref )

=item default_export name { ... }

=item default_export name parser { ... }

=item gen_export( $name )

=item gen_export( $name, $ref )

=item gen_export( $name, $parser )

=item gen_export( $name, $parser, $ref )

=item gen_export name { ... }

=item gen_export name parser { ... }

=item gen_default_export( $name )

=item gen_default_export( $name, $ref )

=item gen_default_export( $name, $parser )

=item gen_default_export( $name, $parser, $ref )

=item gen_default_export name { ... }

=item gen_default_export name parser { ... }

These all act just like export(), except that they add subrefs as generators,
and/or add exports to the -default tag.

=back

=head1 ADDITIONAL TAGS

=head2 -magic

This brings in the magical (L<Devel::Declare>) functions in addition to the
default.

=over 4

=item -default

=item export

=item gen_export

=item default_export

=item gen_default_export

=item parser

=item parsed_exports

=item parsed_default_exports

=back

=head1 INTERNAL API

Exporter/Declare.pm does not have much logic to speak of. Rather
Exporter::Declare is sugar on top of class meta data stored in
L<Exporter::Declare::Meta> objects. Arguments are parsed via
L<Exporter::Declare::Specs>, and also turned into objects. Even exports are
blessed references to the exported item itself, and handle the injection on
their own (See L<Exporter::Declare::Export>).

=head1 META CLASS

All exporters have a meta class, the only way to get the meta object is to call
the exporter_meta() method on the class/object that is an exporter. Any class
that uses Exporter::Declare gets this method, and a meta-object.

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Exporter-Declare is free software; Standard perl licence.

Exporter-Declare is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the license for more details.
