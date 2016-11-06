# Kernel/Modules/AgentCartridgeSearch.pm - a module used for the autocomplete feature
# Copyright (C) 2009-2013 Radiant Sysetms, http://www.radiants.ru
# Copyright (C) 2016 jeen, http://www.jeen.me
#
# --
# $Id: AgentCartridgeSearch.pm,v 1.0 2013-01-21 11:23:22 Artjoms Petrovs Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::CustomerConfigItemSearch;

use strict;
use warnings;

use Kernel::System::GeneralCatalog;
use Kernel::System::ITSMConfigItem;
use Kernel::System::CustomerUser;

use Data::Dumper;


use vars qw($VERSION);
$VERSION = qw($Revision: 1.2 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check all needed objects
    for my $Object (
        qw(ParamObject DBObject LayoutObject ConfigObject LogObject)
        )
    {
        if ( !$Self->{$Object} ) {
            $Self->{LayoutObject}->FatalError( Message => "AgentServiceSearch: Got no $Object!" );
        }
    }


    $Self->{GeneralCatalogObject} = Kernel::System::GeneralCatalog->new(%Param);
    $Self->{ConfigItemObject}     = Kernel::System::ITSMConfigItem->new(%Param);
    $Self->{CustomerUserObject}   = Kernel::System::CustomerUser->new(%Param);

	
    return $Self;
}

sub Run {
my ( $Self, %Param ) = @_;

    my $JSON = '';

    # get needed params
    my $Search        = $Self->{ParamObject}->GetParam( Param => 'Term' ) || '';
    my $CustomerLogin = $Self->{ParamObject}->GetParam( Param => 'CustomerSelected' ) || '';

    my @CustomerIDs;
    my @DeplStateIDs = (32); # default value for deployed and working CMDB item
    if ( $CustomerLogin ) {

#       my %User = $Self->{CustomerUserObject}->CustomerUserDataGet(
#          User => $CustomerLogin,
#       );

#       push @CustomerIDs, $User{CustomerID};

       @CustomerIDs = $Self->{CustomerUserObject}->CustomerIDs(
          User => $CustomerLogin,
       );


    }
    else {

       @CustomerIDs = $Self->{CustomerUserObject}->CustomerIDs(
          User => $Self->{UserID},
       );

#       push @CustomerIDs, $Self->{CustomerID};
    }


    # workaround, all auto completion requests get posted by utf8 anyway
    # convert any to 8bit string if application is not running in utf8
    if ( !$Self->{EncodeObject}->EncodeInternalUsed() ) {
        $Search = $Self->{EncodeObject}->Convert(
            Text => $Search,
            From => 'utf-8',
            To   => $Self->{LayoutObject}->{UserCharset},
        );
    }

    # Exception for ** search (PERL bug fix)
#    if ($Search eq '**'){
#       $Search = '';
#    }

    $Search =~ s/\*//gsi;

#$Self->{LogObject}->Log( Priority => 'error', Message => "CI Search 003 ".$CustomerID." 123 ".$Self->{CustomerID}." !" );

#    if ( !$CustomerID and $Self->{CustomerID} ) {
#       $CustomerID = $Self->{CustomerID};
#    }


#$Self->{LogObject}->Log( Priority => 'error', Message => "CI Search 001 ".Dumper(@CustomerIDs)." !" );

    my $ConfigItemIDs = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
	DeplStateIDs => [@DeplStateIDs],
	What             => [{"[%]{'Version'}[%]{'Owner'}[%]{'Content'}" => [@CustomerIDs]}],
#       What             => [{
#                              "[%]{'Version'}[%]{'Owner'}[%]{'Content'}" => $Self->{CustomerID},
#                              "[%]{'Version'}[%]{'ServiceNumber'}[%]{'Content'}" => "\%$Search%"
#       }],


#       Name             => "\%$Search%",
#       ClassIDs         => [$ClassID],
#       DeplStateIDs     => $DeplStateIDs,
       OrderBy          => ['Number'],
       OrderByDirection => ['Down'],
       Limit            => 10000,
    );


#$Self->{LogObject}->Log( Priority => 'error', Message => "CI Search 001 ".scalar @{$ConfigItemIDs}." !" );


#$Self->{LogObject}->Log( Priority => 'error', Message => "CI Search 001 ".Dumper($ConfigItemIDs)." !" );


    # build data
    my @Data;

    if ( scalar @{$ConfigItemIDs} > 0 ) {
       for my $ConfigItemID ( @{$ConfigItemIDs}  ) {

          my $VersionList = $Self->{ConfigItemObject}->VersionZoomList(
             ConfigItemID => $ConfigItemID,
          );

          my $Version = $Self->{ConfigItemObject}->VersionGet(
             VersionID => $VersionList->[-1]->{VersionID},
          );

#$Self->{LogObject}->Log( Priority => 'error', Message => "CI Search 001 ".Dumper($Version)." !" );

#                                 "[%]{'Version'}[%]{'ServiceNumber'}[%]{'Content'}" => "\%$Search%"

          if ( $Version->{XMLData}->[-1]->{Version}->[-1]->{ ServiceNumber }->[-1]->{Content} =~ /.*?$Search.*?/ ) {

          push @Data, {
             Key   => $ConfigItemID,
             Value => $Version->{Name}.' '.$Version->{XMLData}->[-1]->{Version}->[-1]->{ ServiceNumber }->[-1]->{Content},
          };
          }

       }
    }


    # build JSON output
    $JSON = $Self->{LayoutObject}->JSONEncode(
        Data => \@Data,
    );

    # send JSON response
    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
}

1;
