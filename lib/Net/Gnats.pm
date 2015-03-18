package Net::Gnats;
use 5.010_000;
use utf8;
use strict;
use warnings;
use Readonly;
use English '-no_match_vars';

require Exporter;
use base 'Exporter';

use IO::Socket::INET;
use Net::Gnats::PR;
use Net::Gnats::Response;

our $VERSION = '0.11';
our @CARP_NOT;
$OUTPUT_AUTOFLUSH = 1;

Readonly::Scalar my $NL                          => "\n";
Readonly::Scalar my $DOT                         => q{.};

Readonly::Scalar my $CODE_GREETING               => 200;
Readonly::Scalar my $CODE_CLOSING                => 201;
Readonly::Scalar my $CODE_OK                     => 210;
Readonly::Scalar my $CODE_SEND_PR                => 211;
Readonly::Scalar my $CODE_SEND_TEXT              => 212;
Readonly::Scalar my $CODE_NO_PRS_MATCHED         => 220;
Readonly::Scalar my $CODE_NO_ADM_ENTRY           => 221;
Readonly::Scalar my $CODE_PR_READY               => 300;
Readonly::Scalar my $CODE_TEXT_READY             => 301;
Readonly::Scalar my $CODE_INFORMATION            => 350;
Readonly::Scalar my $CODE_INFORMATION_FILLER     => 351;
Readonly::Scalar my $CODE_NONEXISTENT_PR         => 400;
Readonly::Scalar my $CODE_EOF_PR                 => 401;
Readonly::Scalar my $CODE_UNREADABLE_PR          => 402;
Readonly::Scalar my $CODE_INVALID_PR_CONTENTS    => 403;
Readonly::Scalar my $CODE_INVALID_FIELD_NAME     => 410;
Readonly::Scalar my $CODE_INVALID_ENUM           => 411;
Readonly::Scalar my $CODE_INVALID_DATE           => 412;
Readonly::Scalar my $CODE_INVALID_FIELD_CONTENTS => 413;
Readonly::Scalar my $CODE_INVALID_SEARCH_TYPE    => 414;
Readonly::Scalar my $CODE_INVALID_EXPR           => 415;
Readonly::Scalar my $CODE_INVALID_LIST           => 416;
Readonly::Scalar my $CODE_INVALID_DATABASE       => 417;
Readonly::Scalar my $CODE_INVALID_QUERY_FORMAT   => 418;
Readonly::Scalar my $CODE_NO_KERBEROS            => 420;
Readonly::Scalar my $CODE_AUTH_TYPE_UNSUP        => 421;
Readonly::Scalar my $CODE_NO_ACCESS              => 422;
Readonly::Scalar my $CODE_LOCKED_PR              => 430;
Readonly::Scalar my $CODE_GNATS_LOCKED           => 431;
Readonly::Scalar my $CODE_GNATS_NOT_LOCKED       => 432;
Readonly::Scalar my $CODE_PR_NOT_LOCKED          => 433;
Readonly::Scalar my $CODE_INVALID_FTYPE_PROPERTY => 435;
Readonly::Scalar my $CODE_CMD_ERROR              => 440;
Readonly::Scalar my $CODE_WRITE_PR_FAILED        => 450;
Readonly::Scalar my $CODE_ERROR                  => 600;
Readonly::Scalar my $CODE_TIMEOUT                => 610;
Readonly::Scalar my $CODE_NO_GLOBAL_CONFIG       => 620;
Readonly::Scalar my $CODE_INVALID_GLOBAL_CONFIG  => 621;
Readonly::Scalar my $CODE_NO_INDEX               => 630;
Readonly::Scalar my $CODE_FILE_ERROR             => 640;

# bits in fieldinfo(field, flags) has (set=yes not-set=no) whether the
# send command should include the field
Readonly::Scalar my $SENDINCLUDE                 => 1;

# whether change to a field requires reason
Readonly::Scalar my $REASONCHANGE                => 2;

# if set, can't be edited
Readonly::Scalar my $READONLY                    => 4;

# if set, save changes in Audit-Trail
Readonly::Scalar my $AUDITINCLUDE                => 8;

# whether the send command _must_ include this field
Readonly::Scalar my $SENDREQUIRED                => 16;

# The possible values of a server reply type.  $REPLY_CONT means that
# there are more reply lines that will follow, $REPLY_END Is the final
# line.
Readonly::Scalar my $REPLY_CONT                  => 1;
Readonly::Scalar my $REPLY_END                   => 2;

# This was found as an 'arbitrary' restart value.
Readonly::Scalar my $RESTART_CHECK_THRESHOLD     => 5;

# Various PR field names that should probably not be referenced in
# here.
#

# Actually, the majority of uses are probably OK--but we need to map
# internal names to external ones.  (All of these field names
# correspond to internal fields that are likely to be around for a
# long time.)
#

Readonly::Scalar my $CATEGORY_FIELD              => 'Category';
Readonly::Scalar my $SYNOPSIS_FIELD              => 'Synopsis';
Readonly::Scalar my $SUBMITTER_ID_FIELD          => 'Submitter-Id';
Readonly::Scalar my $ORIGINATOR_FIELD            => 'Originator';
Readonly::Scalar my $AUDIT_TRAIL_FIELD           => 'Audit-Trail';
Readonly::Scalar my $RESPONSIBLE_FIELD           => 'Responsible';
Readonly::Scalar my $LAST_MODIFIED_FIELD         => 'Last-Modified';

Readonly::Scalar my $NUMBER_FIELD                => 'builtinfield:Number';
Readonly::Scalar my $STATE_FIELD                 => 'State';
Readonly::Scalar my $UNFORMATTED_FIELD           => 'Unformatted';
Readonly::Scalar my $RELEASE_FIELD               => 'Release';
Readonly::Scalar my $REPLYTO_FIELD               => 'Reply-To';

BEGIN {
  # Create aliases to deprecate 'old' style method calls.
  # These will be removed in the 'future'.
  *getDBNames = \&get_dbnames;
  *listDatabases = \&list_databases;
  *listCategories = \&list_categories;
  *listSubmitters = \&list_submitters;
  *listResponsible = \&list_responsible;
  *listStates = \&list_states;
  *listFieldNames = \&list_fieldnames;
  *listInitialInputFields = \&list_inputfields_initial;
  *getFieldType = \&get_field_type;
  *getFieldTypeInfo = \&get_field_typeinfo;
  *getFieldDesc = \&get_field_desc;
  *getFieldFlags = \&get_field_flags;
  *getFieldValidators = \&get_field_validators;
  *getFieldDefault = \&get_field_default;
  *getAccessMode = \&get_access_mode;
  *getErrorCode = \&get_error_code;
  *getErrorMessage = \&get_error_message;

  *setWorkingEmail = \&set_workingemail;
  *replaceField = \&truncate_field_content;
  *appendToField = \&append_field_content;

  *validateField = \&validate_field;
  *isValidField = \&is_validfield;

  *checkNewPR = \&check_newpr;

  *lockPR   = \&lock_pr;
  *unlockPR = \&unlock_pr;
  *deletePR = \&delete_pr;
  *checkPR  = \&check_pr;
  *submitPR = \&submit_pr;
  *updatePR = \&update_pr;
  *newPR = \&new_pr;
  *getPRByNumber = \&get_pr_by_number;

  *resetServer = \&reset_server;
  *lockMainDatabase = \&lock_main_database;
  *unlockMainDatabase = \&unlock_main_database;
}

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Net::Gnats ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

my $debug_gnatsd = 0;

# There is a bug in gnatsd that seems to happen after submitting
# about 125 new PR's in the same session it starts thinking that
# the submitter-id is not valid anymore, so we restart every so often.
Readonly::Scalar my $MAX_NEW_PRS => 100;

#******************************************************************************
# Sub: new
# Description: Constructor
# Args: hash (parameter list)
# Returns: self
#******************************************************************************
sub new {
    my ( $class, $host, $port ) = @_;
    my $self = bless {}, $class;

    $self->{hostAddr} = $host || 'localhost';
    $self->{hostPort} = $port || '1529';

    $self->{fieldData} = {
                          # Array of fieldnames in same order
                          # returned by list fieldnames.
                          names => [],
                          # Initial Input Fields
                          initial => [],
                          # All the field info.
                          fields => {},
                         };

    $self->{lastCode} = undef;
    $self->{lastResponse} = undef;
    $self->{errorCode} = undef;
    $self->{errorMessage} = undef;
    $self->{accessMode} = undef;
    $self->{gnatsdVersion} = undef;
    $self->{user} = undef;
    $self->{db}   = undef;

    return $self;
}

sub debug_gnatsd {
  $debug_gnatsd = 1;
  return;
}

sub _gsock {
  my ($self, $value) = @_;
  if (defined $value) {
    $self->{ sock } = $value;
  }
  return $self->{sock};
}

sub gnatsd_connect {
    my ( $self ) = @_;
    my ( $sock, $iaddr, $paddr, $proto );

    if ( defined $self->_gsock ) {
      $self->disconnect;
    }

    my $socket = IO::Socket::INET->new( PeerAddr => $self->{ hostAddr },
                                        PeerPort => $self->{ hostPort },
                                        Proto    => 'tcp');

    if ( not defined $socket ) {
      debug('$socket is not defined.');
      return;
    }

    $self->_gsock( $socket );


    #TODO disconnect if already connected

#    if ( ! ( $iaddr = inet_aton($self->{hostAddr} ) ) ) {
#        carp("Unknown GNATS host '$self->{hostAddr}'");
#        return 0;
#    }

#    $paddr = sockaddr_in( $self->{ hostPort }, $iaddr);
#    $proto = getprotobyname 'tcp' ;
#    if ( not socket $sock, PF_INET, SOCK_STREAM, $proto ) {
      #TODO: RECOVER BETTER HERE
#      carp "gnatsweb: client_init error $self->{hostAddr} $self->{hostPort}: $OS_ERROR";
#      return 0;
#    }


#    if ( not connect $self->_gsock, $paddr ) {
      #TODO: RECOVER BETTER HERE
#      carp "gnatsweb: client_init error $self->{hostAddr} $self->{hostPort}: $OS_ERROR ;";
#      return 0;
#    }

#    $self->_gsock->autoflush(1);
    my $response = $self->_get_gnatsd_response();

    $self->{lastCode} = defined $response->code ? $response->code : undef;
    $self->{lastResponse} = $response->as_string;
    debug('INIT: [' . $response->as_string . ']');

    # Make sure we got a 200 code.
    if ($response->code != $CODE_GREETING) {
      logerror("Unknown gnatsd connection response: $response");
      return 0;
    }

    # Grab the gnatsd version
    my $gversion = pop @{ $response->raw };
    if ( $gversion =~ /\d.\d.\d/ ) {
      $self->{gnatsdVersion} = $gversion;
      $self->{gnatsdVersion} =~ s/.*(\d.\d.\d).*/$1/g;
    }
    else {
      # We only know how to talk to gnats4
      warn "? Error: GNATS Daemon version $self->{gnatsdVersion} at $self->{hostAddr} $self->{hostPort} is not supported by Net::Gnats\n";
      return 0;
    }
    $self->{newPRs} = 0;
    return 1;
}

sub disconnect {
    my ( $self ) = @_;
    $self->_do_gnats_cmd('QUIT');
    $self->{sock}->close;
    return 1;
}

sub get_dbnames {
    my ( $self ) = @_;

    my $r = $self->_do_gnats_cmd('DBLS');
    debug('DBLS CODE: [' . $r->code . ']');

    return $r->raw if $r->code == $CODE_TEXT_READY;

    $self->_mark_error($r);
    return;
}


sub list_databases {
    return shift->_list('DATABASES',
                        ['name', 'desc', 'path']);
}


sub list_categories {
    return shift->_list('CATEGORIES',
                        ['name', 'desc', 'contact', 'notify']);
}

sub list_submitters {
    return shift->_list('SUBMITTERS',
                        ['name', 'desc', 'contract', 'response',
                         'contact', 'othernotify']);
}

sub list_responsible {
    return shift->_list('RESPONSIBLE',
                        ['name', 'realname', 'email']);
}

sub list_states {
    return shift->_list('STATES',
                        ['name', 'type', 'desc']);
}

sub list_fieldnames {
  my ( $self ) = @_;
  my $r = $self->_do_gnats_cmd('LIST FIELDNAMES');
  return $r->raw if $r->code == $CODE_TEXT_READY;
  return;
}

sub list_inputfields_initial {
  my ( $self ) = @_;

  if ($#{$self->{fieldData}->{initial}} < 0) {
    my $r = $self->_do_gnats_cmd('LIST INITIALINPUTFIELDS');

    if ($r->code != $CODE_TEXT_READY) {
      $self->_mark_error($r);
      return;
    }

    push @{$self->{fieldData}->{initial}}, @{$r->raw};
  }
  return $self->{fieldData}->{initial};
}

sub list_inputfields_initial_required {
  my ( $self ) = @_;

  if ($#{$self->{fieldData}->{initial}} < 0) {
    my $r = $self->_do_gnats_cmd('LIST INITIALREQUIREDFIELDS');

    if ($r->code != $CODE_TEXT_READY) {
      $self->_mark_error($r);
      return;
    }

    push @{$self->{fieldData}->{initial}}, @{$r->raw};
  }
  return wantarray ? @{$self->{fieldData}->{initial}} : $self->{fieldData}->{initial};
}



sub get_field_type {
  my ( $self, $field ) = @_;

  if (not defined $field) { return; }

  my $r = $self->_do_gnats_cmd("FTYP $field");

  if ( $r->code == $CODE_INVALID_FIELD_NAME ) { return; }

  # only one value should be returned
  return shift @{ $r->raw };
}

sub is_validfield {
  my ( $self, $field ) = @_;
  if (not exists($self->{validFields}->{$field})) {
    $self->{validFields}->{$field} = $self->getFieldType($field) ? 1 : 0
  }
  return $self->{validFields}->{$field};
}

sub get_field_typeinfo {
  my ( $self, $field, $property ) = @_;
  if ( not defined $field ) { return; }
  my $type_response = $self->get_field_type($field);

  debug('FTYP (response): [' . $type_response . ']');

  if ( $type_response ne 'MultiEnum' ) { return; }
  if ( not defined $property ) { $property = 'separators'; }


  my $r = $self->_do_gnats_cmd("FTYPINFO $field $property");
  if ( $r->code == $CODE_INVALID_FTYPE_PROPERTY ) { return; }
  return $r->raw;
}

sub get_field_desc {
  my ( $self, $field ) = @_;

  my $r = $self->_do_gnats_cmd("FDSC $field");
  return shift @{ $r->raw } if $r->code == $CODE_INFORMATION;

  $self->_mark_error($r);
  return;
}

sub get_field_flags {
  my ( $self, $field, $flag ) = @_;

  if ( not defined $field ) { return; }

  my $r = $self->_do_gnats_cmd("FIELDFLAGS $field");

  if (defined $flag and $r->raw =~ /$flag/sxm) { return 1; }

  return $r->raw;
}

sub get_field_validators {
    my ( $self, $field ) = @_;

    return if not defined $field;

    my $r = $self->_do_gnats_cmd("FVLD $field");

    return $r->raw if $r->code == $CODE_TEXT_READY;

    if ( $r->code == $CODE_INVALID_FIELD_NAME ) {
      $self->_mark_error($r);
      return;
    }

    return;
}


sub validate_field {
  my ( $self, $field, $input ) = @_;

  return if not defined $field or not defined $input;

  my $r = $self->_do_gnats_cmd("VFLD $field");

  return if $r->code != $CODE_SEND_TEXT;

  $r = $self->_do_gnats_cmd($input . $NL . q{.});

  if ( $r->code != $CODE_OK ) {
    logerror('ERROR: [' . $r->code . '] when supplying VFLD text on [' . $field . ']');
    return;
  }

  # Return last response object in future
  return 1;
}

sub get_field_default {
  my ( $self, $field ) = @_;
  my $r = $self->_do_gnats_cmd("INPUTDEFAULT $field");
  return if $r->code != $CODE_OK;
  return @{ $r->raw }[0];
}


sub reset_server {
  my ( $self ) = @_;

  my $r = $self->_do_gnats_cmd('RSET');

  # CODE_CMD_ERROR (440) can never happen since we constrain no args in code.

  if ( $r->code >= $CODE_ERROR ) {
    logerror( 'ERROR [' . $r->code . ']: ' . $r->raw );
    return;
  }

  return 1;
}


sub lock_main_database {
  my ( $self ) = @_;

  my $r = $self->_do_gnats_cmd('LKDB');

  logerror('ERROR: CODE_GNATS_LOCKED: Gnats database already locked.')
    and return
    if $r->code == $CODE_GNATS_LOCKED;

  logerror('ERROR: CODE_CMD_ERROR')
    and return
    if $r->code == $CODE_CMD_ERROR;

  logerror( 'ERROR [' . $r->code . ']: ' . $r->raw )
    and return
    if $r->code >= $CODE_ERROR;

  return if $r->code == -1;

  return 1;
}

sub unlock_main_database {
  my ( $self ) = @_;

  my $r = $self->_do_gnats_cmd('UNDB');

  # CODE_CMD_ERROR (440) can never happen since we constrain no args
  # in code.
  logerror('ERROR: CODE_GNATS_NOT_LOCKED: Gnats database not locked.')
    and return
    if $r->code == $CODE_GNATS_NOT_LOCKED;

  # Test this with a user who does not have privelege to lock
  # database.
  logerror( 'ERROR [' . $r->code . ']: ' . $r->raw )
    and return
    if $r->code >= $CODE_ERROR;

  return 1;
}

sub lock_pr {
  my ( $self, $pr_number, $user ) = @_;

  return if not defined $pr_number or not defined $user;

  my $r = $self->_do_gnats_cmd("LOCK $pr_number $user");

  logerror( 'ERROR: CODE_CMD_ERROR: ' . $r->raw )
    and return
    if $r->code == $CODE_CMD_ERROR;

  logerror( 'ERROR: CODE_NONEXISTENT_PR: ' . $r->raw )
    and return
    if $r->code == $CODE_NONEXISTENT_PR;

  logerror( 'ERROR: CODE_LOCKED_PR: ' . $r->raw )
    and return
    if $r->code == $CODE_LOCKED_PR;

  # Test this with a user who does not have privelege to lock the PR.
  logerror( 'ERROR [' . $r->code . ']: ' . $r->raw )
    and return
    if $r->code >= $CODE_ERROR;

  # CODE_PR_READY (300)
  my $pr = Net::Gnats::PR->new( $self );
  $pr->parse( $r->raw );
  return $pr;
}

sub unlock_pr {
  my ( $self, $pr ) = @_;

  logerror( 'ERROR: unlock_pr requires PR number' )
    and return
    if not defined $pr;

  my $r = $self->_do_gnats_cmd( 'UNLK ' . $pr );

  return 1 if $r->code == $CODE_OK;

  logerror( 'ERROR: CODE_CMD_ERROR: ' . $r->raw)
    and return
    if $r->code == $CODE_CMD_ERROR;

  logerror( 'ERROR: CODE_NONEXISTENT_PR: ' . $r->raw )
    and return
    if $r->code == $CODE_NONEXISTENT_PR;

  logerror( 'ERROR: CODE_PR_NOT_LOCKED: ' . $r->raw )
    and return
    if $r->code == $CODE_PR_NOT_LOCKED;

  # Test this with a user who does not have privelege to lock the PR.
  logerror( 'ERROR [' . $r->code . ']: ' . $r->raw )
    and return
    if $r->code >= $CODE_ERROR;

  return;
}

sub delete_pr {
  my ( $self, $pr ) = @_;

  my $r = $self->_do_gnats_cmd('DELETE ' . $pr->getField('Number'));

  return 1 if $r->code == $CODE_OK;

  logerror('You do not have access to delete this PR.')
    and return
    if $r->code == $CODE_NO_ACCESS;

  logerror('You cannot delete a locked PR.')
    and return
    if $r->code == $CODE_LOCKED_PR;

  logerror('Cannot delete, Gnats DB is currently locked.')
    and return
    if $r->code == $CODE_GNATS_LOCKED;

  logerror('PR nonexistent.')
    and return
    if $r->code == $CODE_NONEXISTENT_PR;

  logerror('Unexpected error [' . $r->code . '] occurred. PR not deleted.');
  return;
}

sub check_newpr {
  my ( $self, $pr ) = @_;
  $self->check_pr($pr, 'initial');
  return;
}

sub chek {
  my ( $self, $initial ) = @_;

  $initial = defined $initial ? 'initial' : '';

  my $r = $self->_do_gnats_cmd("CHEK $initial");

  # TODO: Add logging
  return 1 if $r->code == $CODE_SEND_PR;

  # TODO: Add logging
  return undef if $r->code == $CODE_CMD_ERROR;

  logerror('Unexpected error [' . $r->code . '] occurred. PR not deleted.');
  return;
}


sub check_pr {
  my ( $self, $pr, $arg ) = @_;

  my $argument  = defined $arg ? $arg : q{};

  my $r = $self->_do_gnats_cmd("CHEK $argument");

  return if $r->code != $CODE_SEND_PR;

  $r = $self->_do_gnats_cmd( $pr . $NL . $DOT );

  return 1 if $r->code == $CODE_OK;

  # TODO: If at this point, there can be "INNER ERRORS" which need to
  # be captured and reported on via Net::Gnats::Response.
  return;
}


sub set_workingemail {
  my ( $self, $email ) = @_;

  my $r = $self->_do_gnats_cmd("EDITADDR $email");

  return 1 if $r->code == $CODE_OK;

  $self->_mark_error($r)
    and return;
}

#
# TODO: "text" fields are limited to 256 characters.  Current gnatsd does
# not correctly truncate, if you enter $input is 257 characters, it will
# replace with an empty field.  We should truncate text $input's correctly.

sub truncate_field_content {
  my ( $self, $pr, $field, $input, $reason ) = @_;
  logerror('? Error: pr not passed to replaceField')
    if not defined $pr;

  logerror('? Error: field passed to replaceField')
    if not defined $field;

  logerror('? Error: no input passed to replaceField')
    if not defined $input;

  # See if this field requires a change reason.
  # TODO: We could just enter the $input, and see if gnatsd says
  #       a reason is required, but I could not figure out how to
  #       abort at that point if no reason was given...
  my $need_reason = $self->getFieldFlags($field, 'requireChangeReason');

  if ($need_reason and ( not defined $reason or $reason eq q{} )) {
    logerror('No change Reason Specified');
    return;
  }

  my $r = $self->_do_gnats_cmd("REPL $pr $field");

  if ( $r->code == $CODE_SEND_TEXT ) {
    $r = $self->_do_gnats_cmd($input . $NL . $DOT);

    if ($need_reason) {
      #warn "reason=\"$reason\"";
      # TODO: This can choke here if we encounter a PR with a bad field like:
      # _getGnatsdResponse: READ >>411 There is a bad value `unknown' for the field `Category'.
      $r = $self->_do_gnats_cmd($reason . $NL . $DOT)
    }

    $self->restart($r->code)
      and return $self->replaceField($pr, $field, $input, $reason)
      if $r->code == $CODE_FILE_ERROR;

    if ($self->_is_code_ok($r->code)) {
      return 1;
    }
    $self->_mark_error($r);

  }

  $self->_mark_error($r );
  return;
}

my $restart_time;

sub restart {
  my ( $self, $code ) = @_;

  my $ctime = time;
  if ( defined $restart_time ) {
    if ( ($ctime - $restart_time) < $RESTART_CHECK_THRESHOLD ) {
      logerror('! ERROR: Restart attempted twice in a row, 640 error must be real!');
      return 0;
    }
  }

  logerror ( $NL
      .  $NL . '! ERROR: Recieved GNATSD code ' . $code . ', will now disconnect and'
      .  $NL . 'reconnecting to gnatsd, then re-issue the command.  This may cause any'
      .  $NL . 'following commands to behave differently if you depended on'
      .  $NL . 'things like QFMT'
      .  $NL . time . $NL );

  $restart_time = $ctime;
  $self->_clear_error();
  $self->disconnect;
  $self->gnatsd_connect;
  return $self->login($self->{db},
                      $self->{user},
                      $self->{pass});
}

sub append_field_content {
  my ( $self, $pr, $field, $input ) = @_;

  logerror('? Error: pr not passed to appendField')
    if not defined $pr;
  logerror('? Error: field passed to appendField')
      if not defined $field;
  logerror('? Error: no input passed to appendField')
    if not defined $input;

  my $r = $self->_do_gnats_cmd("APPN $pr $field");

  if ($self->_is_code_ok($r->code)) {
    $r= $self->_do_gnats_cmd( $input . $NL . $DOT );
    if ($self->_is_code_ok($r->code)) {
      return 1;
    } else {
      $self->_mark_error( $r );
    }
  } else {
    $self->_mark_error($r);
  }
  if ($r->code == $CODE_FILE_ERROR and $self->restart($r->code)) {
    # TODO: This can potentially be an infinte loop...
    return $self->appendToField($pr, $field, $input);
  }
  return 0;
}

sub submit_pr {
  my ( $self, $pr ) = @_;

  if ($self->{newPRs} > $MAX_NEW_PRS) {
    $self->restart('Too Many New PRs');
  }

  my $pr_string = $pr->unparse();

  my $r = $self->_do_gnats_cmd('SUBM');

  if ($r->code == $CODE_GNATS_LOCKED) {
    logerror( 'Gnats database locked, cannot submit PR.' );
    return;
  }

  $r = $self->_do_gnats_cmd($pr_string . $NL . q{.});

  # Returns PR Number. Return this to the caller.
  if ( $r->code == $CODE_INFORMATION or
       $r->code == $CODE_INFORMATION_FILLER ) {
    $self->{newPRs}++;
    return $r->raw;
  }

  # Something unexpected happened.  The client can attempt to resend.
  # Later, give the client the whole response object.
  logerror('ERROR: Unexpected response code [' . $r->code . ']: ' . @{ $r->raw }[0]);
  return;
}

##################################################################
#
# Update the PR.
#
# Bit's of this code were grabbed from "gnatsweb.pl".
#
sub update_pr {
  my ( $self, $pr ) = @_;

  my $last_modified = $pr->getField('Last-Modified');
  $last_modified ||= q{}; # Default to empty

  my $pr_string = $pr->unparse('gnatsd');

  my $code; my $response ; my $st = 0;

  # Lock the PR so we can edit it.
  # Locking it returns the PR contents which we use to see what has changed.
  my $spr = $self->lock_pr($pr->getField('Number'),
                           $self->{user});

  return $st if not defined $spr;

  # See which fields changed.
  my %spr_hash = $spr->asHash();
  $spr_hash{'Last-Modified'} ||= q{};

  # Make sure modified date is the same!
  my $slast_modified = $spr->getField('Last-Modified');
  $slast_modified ||= q{}; # Default to empty

  if ($last_modified ne $slast_modified) {
    logerror('Someone modified the PR. Refresh the PR and try again.');
    return;
  }

  my $r = $self->_do_gnats_cmd('EDITADDR ' . $self->{user});

  logerror('ERROR: EDITADDR: ' . $r->raw)
    and return
    if $r->code == $CODE_CMD_ERROR;

  $r = $self->_do_gnats_cmd('EDIT ' . $pr->getField('Number'));

  logerror('ERROR: EDIT: CODE_GNATS_LOCKED: ' . $r->raw)
    and return
    if $r->code == $CODE_GNATS_LOCKED;

  logerror('ERROR: EDIT: CODE_PR_NOT_LOCKED: ' . $r->raw)
    and return
    if $r->code == $CODE_PR_NOT_LOCKED;

  logerror('ERROR: EDIT: CODE_NONEXISTENT_PR: ' . $r->raw)
    and return
    if $r->code == $CODE_NONEXISTENT_PR;

  $r = $self->_do_gnats_cmd( $pr_string . q{.} );

  logerror('ERROR: EDIT: FILING FAILED: ' . $r->raw)
    and return
    if $r->code != $CODE_OK;

  $self->unlock_pr($pr->getField('Number'));

  return 1;
}


sub new_pr {
  my ( $self ) = @_;

  my $pr = Net::Gnats::PR->new($self);

  foreach my $field ($self->listInitialInputFields) {
    $pr->setField($field,
                  $self->getFieldDefault( $field ) );
  }
  return $pr;
}

sub get_pr_by_number {
  my ( $self, $num ) = @_;

  if ( not defined $self->reset_server ) {
    return;
  }

  my $r = $self->_do_gnats_cmd('QFMT full');

  $self->_mark_error($r)
    and return
    if not $self->_is_code_ok($r->code);

  $r = $self->_do_gnats_cmd("QUER $num");

  debug('CODE: ' . $r->code );
  debug('RESPONSE: ' . @{ $r->raw }[0] );

  return if $r->code == $CODE_NO_PRS_MATCHED;


  $self->_mark_error($r)
    and return
    if not $self->_is_code_ok($r->code);

  my $pr = $self->new_pr();
  $pr->parse( @{ $r->raw } ) ;

  return $pr;
}


sub expr {
  my $self = shift;
  my @exprs = @_;
  return if scalar @exprs == 0;

  foreach my $expr (@exprs) {
    my $r = $self->_do_gnats_cmd("EXPR $expr");
    return if $r->code == $CODE_INVALID_EXPR;
  }

  return 1;
}

# Because we don't know what's in the dbconfig file, we will only
# support FULL, STANDARD, and SUMMARY since those must be defined.
# Otherwise, we assume it is a custom format.
sub qfmt {
  my ($self, $format) = @_;

  # If format is not defined, then defaults to STANDARD
  # This is per the GNATS specification.
  $format = 'standard' if not defined $format;

  my $r = $self->_do_gnats_cmd("QFMT $format");

  return 1 if $r->code == $CODE_OK;
  return   if $r->code == $CODE_CMD_ERROR;
  return   if $r->code == $CODE_INVALID_QUERY_FORMAT;
  return;
}

sub query {
  my $self = shift;
  my @exprs = @_;

  return if not defined $self->reset_server;
  return if not defined $self->qfmt('full');
  return if not defined $self->expr(@exprs);

  my $r = $self->_do_gnats_cmd('QUER');
  return $r->raw if $r->code == $CODE_PR_READY;
  return []      if $r->code == $CODE_NO_PRS_MATCHED;
  return         if $r->code == $CODE_INVALID_QUERY_FORMAT;
  return;
}

sub _list {
  my ( $self, $listtype, $keynames ) = @_;

  my $r = $self->_do_gnats_cmd("LIST $listtype");

  if (not $self->_is_code_ok($r->code)) {
    $self->_mark_error($r);
    return;
  }

  my $result = [];
  foreach my $row (@{ $r->raw }) {
    my @parts = split ':', $row;
    push @{ $result}, { map { @{ $keynames }[$_] =>
                                $parts[$_] } 0..( scalar @{$keynames} - 1) };
  }
  return $result;
}

sub login {
  my ( $self, $db, $user, $pass ) = @_;

  if ( not defined $pass or $pass eq q{} ) {
    $pass = q{*};
  }

  my $r = $self->_do_gnats_cmd("CHDB $db $user $pass");

  if ( $r->code == $CODE_OK ) {
    $self->{db}   = $db;
    $self->{user} = $user;
    $self->{pass} = $pass;
    $self->_set_access_mode;
    return 1;
  }

  if ( $r->code == $CODE_NO_ACCESS ) {
    logerror( 'ERROR: CODE_NO ACCESS: ' . $r->raw );
    return;
  }

  if ( $r->code == $CODE_INVALID_DATABASE ) {
    logerror( 'ERROR: CODE_NO ACCESS: ' . $r->raw );
    return;
  }

  logerror( 'ERROR: LOGIN: UNKNOWN RESPONSE: ' . $r->raw );
  return;
}

# Specify the user for database access.
# A 350 is not returned in this case.
sub cmd_user {
  my ( $self, $user, $pass) = @_;

  return if not defined $user or not defined $pass;

  my $r = $self->_do_gnats_cmd("USER $user $pass");

  if ( $r->code == $CODE_OK ) {
    $self->_set_access_mode;
    return 1;
  }

  if ( $r->code == $CODE_NO_ACCESS ) {
    logerror( 'ERROR: CODE_NO_ACCESS: ' . $r->raw );
    return
  }

  logerror( 'ERROR: LOGIN: UNKNOWN RESPONSE: ' . $r->raw );
  return;
}


sub get_access_mode {
    my ( $self ) = @_;
    return $self->{accessMode};
}

# This is called by login to determine the current access mode,
# typically this would not be called by the user.
sub _set_access_mode {
  my ( $self )  = @_;

  $self->{accessMode} = undef;

  my $r = $self->_do_gnats_cmd('USER');

  if ($self->_is_code_ok($r->code)) {
    $self->{accessMode} = shift @{ $r->raw };
    $self->{accessMode} =~ s/.*\n350\s*(\S+)\s*\n/$1/gsm;
    return $self->{accessMode};
  }

  $self->_mark_error($r);
  return 0;
}


sub get_error_code {
    my ( $self ) = @_;
    return $self->{errorCode};
}

sub get_error_message {
    my ( $self ) = @_;
    return $self->{errorMessage};
}

sub _do_gnats_cmd {
  my ( $self, $cmd ) = @_;

  $self->_clear_error();

  debug('SENDING: [' . $cmd . ']');

  $self->_gsock->print( $cmd . $NL );

  my $r = $self->_process;

  return $r;
}

sub _process {
  my ( $self ) = @_;

  my $r = $self->_get_gnatsd_response;

  return $r;
}

# use this routine to get more data from the server such as
# Lists or PRs.
sub _read_multi {
  my ( $self ) = @_;
  my $raw = [];
  while ( my $line = $self->_gsock->getline ) {
    if ( not defined $line ) { last; }
    if ( $line =~ /^[.]\r/sxm) { last; }
    $line = $self->_read_clean($line);

    debug('READ: [' . __LINE__ . '][' . $line . ']');
    my $parts = $self->_read_decompose( $line );

    if ( not $self->_read_has_more( $parts ) ) {
      if ( defined @{ $parts }[0] ) {
        push @{ $raw }, @{ $parts }[2];
      }
      last;
    }
    push @{ $raw }, $line;
  }
  return $raw;
}

sub _read {
  my ( $self ) = @_;
  my $raw = [];
  my $response = Net::Gnats::Response->new;

  my $line = $self->_gsock->getline;

  if ( not defined $line ) { return $response; }

  $line = $self->_read_clean($line);

  debug('READ: [' . __LINE__ . '][' . $line . ']');

  my $result = $self->_read_decompose($line);

  $response->code( @{ $result }[0] );

  if ( $response->code == -1 ) { return $response; }

  if ( not ( $response->code == $CODE_PR_READY           or
             $response->code == $CODE_TEXT_READY         or
             $response->code == $CODE_INFORMATION_FILLER ) ) {
    push @{ $raw }, @{$result}[2];
  }

#  if ( defined ( my $next = $self->_read ) ) {
#    push @{ $raw }, $next->raw;
#  }

  if ( $self->_read_has_more( $result ) ) {
    push @{ $raw } , @{ $self->_read_multi };
  }

  $response->raw( $raw );

  return $response;
}

sub _read_decompose {
  my ( $self, $raw ) = @_;
  my @result = $raw =~ /^(\d\d\d)([- ]?)(.*$)/sxm;
  return \@result;
}

sub _read_has_more {
  my ( $self, $parts ) = @_;
  if ( @{$parts}[0] ) {
    if ( @{$parts}[1] eq q{-} ) {
      return 1;
    }
    elsif ( @{$parts}[0] >= $CODE_PR_READY and @{$parts}[0] < $CODE_INFORMATION) {
      return 1;
    }
    return; # does not pass 'continue' criteria
  }
  return 1; # no code, infer multiline read
}

sub _read_clean {
  my ( $self, $line ) = @_;
  if ( not defined $line ) { return; }

  $line =~ s/[\r\n]//gsm;
  $line =~ s/^[.][.]/./gsm;
  return $line;
}

sub _get_gnatsd_response {
    return shift->_read;
}

sub _extract_list_content {
  my ( $self, $response ) = @_;
  my @lines = split /\n/sxm, $response;
  return @lines;
}

sub _is_code_ok {
  my ( $self, $code ) = @_;

  return 0 if not defined $code;
  return 1 if $code =~ /[23]\d\d/sxm;
  return 0;
}

sub _clear_error {
  my ( $self ) = @_;

  $self->{errorCode} = undef;
  $self->{errorMessage} = undef;

  return;
}


sub _mark_error {
  my ($self, $r) = @_;

  $self->{errorCode} = $r->code;
  $self->{errorMessage} = $r->raw;
  debug('ERROR: CODE: [' . $r->code . '] MSG: [' . $r->raw . ']');

  return;
}

sub debug {
  my ( $message ) = @_;
  if ( not defined $debug_gnatsd) { return; }
  if ( not ( print 'DEBUG: [' . $message . ']' . $NL ) ) {
    logerror ( 'weird - could not print trace string' );
  }
  return;
}

sub logerror {
  print shift . "\n";
}


1;

__END__

=head1 NAME

Net::Gnats - Perl interface to GNU Gnats daemon

=head1 VERSION

0.11

=head1 SYNOPSIS

  use Net::Gnats;
  my $g = Net::Gnats->new;
  $g->gnatsd_connect;
  my @dbNames = $g->get_dbnames;
  $g->login("default","somedeveloper","password");

  my $PRtwo = $g->get_pr_by_number(2);
  print $PRtwo->asString();

  # Change the synopsis
  $PRtwo->replaceField("Synopsis","The New Synopsis String");

  # Change the responsible, which requires a change reason.
  $PRtwo->replaceField("Responsible","joe","Because It's Joe's");

  # Or we can change them this way.
  my $PRthree = $g->get_pr_by_number(3);
  # Change the synopsis
  $PRtwo->setField("Synopsis","The New Synopsis String");
  # Change the responsible, which requires a change reason.
  $PRtwo->setField("Responsible","joe","Because It's Joe's");
  # And change the PR in the database
  $g->updatePR($pr);

  my $new_pr = $g->new_pr();
  $new_pr->setField("Submitter-Id","developer");
  $g->submitPR($new_pr);
  $g->disconnect();


=head1 DESCRIPTION

Net::Gnats provides a perl interface to the gnatsd command set.  Although
most of the gnatsd command are present and can be explicitly called through
Net::Gnats, common gnats tasks can be accompished through some methods
which simplify the process (especially querying the database, editing bugs,
etc).

The current version of Net::Gnats (as well as related information) is
available at http://gnatsperl.sourceforge.net/

=head1 COMMON TASKS


=head2 VIEWING DATABASES

Fetching database names is the only action that can be done on a Gnats
object before logging in via the login() method.

  my $g = Net::Gnats->new;
  $g->gnatsd_connect;
  my @dbNames = $g->getDBNames;

Note that getDBNames() is different than listDatabases(), which
requires logging in first and gets a little more info than just names.

=head2 LOGGING IN TO A DATABASE

The Gnats object has to be logged into a database to perform almost
all actions.

  my $g = Net::Gnats->new;
  $g->gnatsd_connect;
  $g->login("default","myusername","mypassword");


=head2 SUBMITTING A NEW PR

The Net::Gnats::PR object acts as a container object to store
information about a PR (new or otherwise).  A new PR is submitted to
gnatsperl by constructing a PR object.

  my $pr = $g->new_pr;
  $pr->setField("Submitter-Id","developer");
  $pr->setField("Originator","Doctor Wifflechumps");
  $pr->setField("Organization","GNU");
  $pr->setField("Synopsis","Some bug from perlgnats");
  $pr->setField("Confidential","no");
  $pr->setField("Severity","serious");
  $pr->setField("Priority","low");
  $pr->setField("Category","gnatsperl");
  $pr->setField("Class","sw-bug");
  $pr->setField("Description","Something terrible happened");
  $pr->setField("How-To-Repeat","Like this.  Like this.");
  $pr->setField("Fix","Who knows");
  $g->submit_pr($pr);

Obviously, fields are dependent on a specific gnats installation,
since Gnats administrators can rename fields and add constraints.
There are some methods in Net::Gnats to discover field names and
constraints, all described below.

Instead of setting each field of the PR individually, the
setFromString() method is available.  The string that is passed to it
must be formatted in the way Gnats handles the PRs.  This is useful
when handling a Gnats email submission ($pr->setFromString($email))
or when reading a PR file directly from the database.  See
Net::Gnats::PR for more details.


=head2 QUERYING THE PR DATABASE

  my @prNums = $g->query('Number>"12"', "Category=\"$thisCat\"");
  print "Found ". join(":",@prNums)." matching PRs \n";

Pass a list of query expressions to query().  A list of PR numbers of
matching PRs is returned.  You can then pull out each PR as described
next.


=head2 FETCHING A PR

  my $prnum = 23;
  my $PR = $g->get_pr_by_number($prnum);
  print $PR->getField('synopsis');
  print $PR->asString();

The method get_pr_by_number() will return a Net::Gnats::PR object
corresponding to the PR num that was passed to it.  The getField() and
asString() methods are documented in Net::Gnats::PR, but I will note
here that asString() returns a string in the proper Gnats format, and
can therefore be submitted directly to Gnats via email or saved to the
db directory for instance.  Also:

 $pr->setFromString($oldPR->asString() );

 works fine and will result in a duplicate of the original PR object.


=head2 MODIFYING A PR

There are 2 methods of modifying fields in a Net::Gnats::PR object.

The first is to use the replaceField() or appendField() methods which
uses the gnatsd REPL and APPN commands.  This means that the changes
to the database happen immediatly.

  my $prnum = 23;
  my $PR = $g->get_pr_by_number($prnum);
  if (! $PR->replaceField('Synopsis','New Synopsis')) {
    warn "Error replacing field (" . $g->get_error_message . ")\n";
  }

If the field requires a change reason, it must be supplied as the 3rd argument.
  $PR->replaceField('Responsible','joe',"It's joe's problem");

The second is to use the setField() and updatePR() methods which uses
the gnatsd EDIT command.  This should be used when multiple fields of
the same PR are being changed, since the datbase changes occur at the
same time.

  my $prnum = 23;
  my $PR = $g->get_pr_by_number($prnum);
  $PR->setField('Synopsis','New Synopsis');
  $PR->setField('Responsible','joe',"It's joe's problem");
  if (! $g->updatePR($PR) ) {
    warn "Error updating $prNum: " . $g->get_error_message . "\n";
  }


=head1 DIAGNOSTICS

Most methods will return undef if a major error is encountered.

The most recent error codes and messages which Net::Gnats encounters
while communcating with gnatsd are stored, and can be accessed with
the get_error_code() and get_error_message() methods.


=head1 SUBROUTINES/METHODS

=head2 new

Constructor, optionally taking one or two arguments of hostname and
port of the target gnats server.  If not supplied, the hostname
defaults to localhost and the port to 1529.

=head2 gnatsd_connect

Connects to the gnats server.  No arguments.  Returns true if
successfully connected, false otherwise.


=head2 disconnect

Issues the QUIT command to the Gnats server, therby closing the
connection.

=head2 get_dbnames

Issues the DBLS command, and returns a list of database names in the
gnats server.  Unlike listDatabases, one does not need to use the logn
method before using this method.

=head2 list_databases

Issues the LIST DATABASES command, and returns a list of hashrefs with
keys 'name', 'desc', and 'path'.

=head2 list_categories

Issues the LIST CATEGORIES command, and returns a list of hashrefs
with keys 'name', 'desc', 'contact', and '?'.

=head2 list_submitters

Issues the LIST SUBMITTERS command, and returns a list of hashrefs
with keys 'name', 'desc', 'contract', '?', and 'responsible'.

=head2 list_responsible

Issues the LIST RESPONSIBLE command, and returns a list of hashrefs
with keys 'name', 'realname', and 'email'.

=head2 list_states

Issues the LIST STATES command, and returns a list of hashrefs with
keys 'name', 'type', and 'desc'.

=head2 list_fieldnames

Issues the LIST FIELDNAMES command, and returns a list of hashrefs
with key 'name'.

=head2 list_inputfields_initial

Issues the LIST INITIALINPUTFIELDS command, and returns a list of
hashrefs with key 'name'.

=head2 get_field_type

Expects a fieldname as sole argument, and issues the FTYP command.
Returns text response or undef if error.

=head2 get_field_type_info

Expects a fieldname and property as arguments, and issues the FTYPINFO
command.  Returns text response or undef if error.

=head2 get_field_desc

Expects a fieldname as sole argument, and issues the FDSC command.
Returns text response or undef if error.

=head2 get_field_flags

Expects a fieldname as sole argument, and issues the FIELDFLAGS
command.  Returns text response or undef if error.

=head2 get_field_validators

Expects a fieldname as sole argument, and issues the FVLD command.
Returns text response or undef if error.

=head2 validate_field()

Expects a fieldname and a proposed value for that field as argument,
and issues the VFLD command.  Returns true if propose value is
acceptable, false otherwise.

=head2 get_field_default

Expects a fieldname as sole argument, and issues the INPUTDEFAULT
command.  Returns text response or undef if error.

=head2 reset_server

Issues the RSET command, returns true if successful, false otherwise.

=head2 lock_main_database

Issues the LKDB command, returns true if successful, false otherwise.

=head2 unlock_main_database

Issues the UNDB command, returns true if successful, false otherwise.

=head2 lock_pr

Expects a PR number and user name as arguments, and issues the LOCK
command.  Returns true if PR is successfully locked, false otherwise.

=head2 unlock_pr

Expects a PR number a sole argument, and issues the UNLK command.
Returns true if PR is successfully unlocked, false otherwise.

=head2 delete_pr($pr)

Expects a PR number a sole argument, and issues the DELETE command.
Returns true if PR is successfully deleted, false otherwise.

=head2 check_pr

Expects the text representation of a PR (see COMMON TASKS above) as
input and issues the CHEK initial command.  Returns true if the given
PR is a valid entry, false otherwise.

=head2 set_workingemail

Expects an email address as sole argument, and issues the EDITADDR
command.  Returns true if email successfully set, false otherwise.

=head2 truncate_field_content

Expects a PR number, a fieldname, a replacement value, and optionally
a changeReason value as arguments, and issues the REPL command.
Returns true if field successfully replaced, false otherwise.

If the field has requireChangeReason attribute, then the changeReason
must be passed in, otherwise the routine will return false.

replaceField changes happen immediatly in the database.  To change
multiple fields in the same PR it is more efficiant to use updatePR.

=head2 append_field_content

Expects a PR number, a fieldname, and a append value as arguments, and
issues the APPN command.  Returns true if field successfully appended
to, false otherwise.

=head2 submit_pr

Expect a Gnats::PR object as sole argument, and issues the SUMB
command.  Returns true if PR successfully submitted, false otherwise.

=head2 update_pr

Expect a Gnats::PR object as sole argument, and issues the EDIT
command.  Returns true if PR successfully submitted, false otherwise.

Use this instead of replace_field if more than one field has changed.

=head2 get_pr_by_number()

Expects a number as sole argument.  Returns a Gnats::PR object.

=head2 query()

Expects one or more query expressions as argument(s).  Returns a list
of PR numbers.

=head2 login()

Expects a database name, user name, and password as arguments and
issues the CHDB command.  Returns true if successfully logged in,
false otherwise

=head2 get_access_mode()

Returns the current access mode of the gnats database.  Either "edit",
"view", or undef;

=head1 INCOMPATIBILITIES

This library is not compatible with the Gnats protocol prior to GNATS
4.

=head1 BUGS AND LIMITATIONS

Bug reports are very welcome.  Please submit to the project page
(noted below).

=head1 CONFIGURATION AND ENVIRONMENT

No externalized configuration or environment at this time.

=head1 DEPENDENCIES

No runtime dependencies other than the Perl core at this time.

=head1 AUTHOR

Current Maintainer:
Richard Elberger riche@cpan.org

Original Author:
Mike Hoolehan, <lt>mike@sycamore.us<gt>

Contributions By:
Jim Searle, <lt>jims2@cox.net<gt>
Project hosted at sourceforge, at http://gnatsperl.sourceforge.net

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2014, Richard Elberger.  All Rights Reserved.

Copyright (c) 1997-2003, Mike Hoolehan. All Rights Reserved.

This module is free software. It may be used, redistributed,
and/or modified under the same terms as Perl itself.

=cut
