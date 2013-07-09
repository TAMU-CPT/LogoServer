package LogoServer::Controller::Root;
use Moose;
use namespace::autoclean;
use Data::Printer;
use Try::Tiny;
use Data::UUID;
use File::Path qw( make_path );
use File::Copy;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(
  namespace => '',
);

# set up the REST response serializing.
__PACKAGE__->config(
  default   => 'text/html',
  stash_key => 'rest',
  "map"     => {
    "application/json"   => "JSON",
    "application/x-yaml" => "YAML",
    "application/yaml"   => "YAML",
    "text/html"          => [ "View", "HTML" ],
    "text/plain"         => [ "View", "Text" ],
    "text/x-yaml"        => "YAML",
    "text/xml"           => "XML::Simple",
    "application/xml"    => "XML::Simple",
    "text/yaml"          => "YAML",
    "image/png"          => [ 'Callback', {
                                            deserialize => \&_deserialize_image,
                                            serialize   => \&_serialize_image,
                                          }
                            ],
  }
);

=head1 NAME

LogoServer::Controller::Root - Root Controller for LogoServer

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

=head2 index

=cut

sub index : Path : Args(0) : ActionClass('REST::ForBrowsers') {
  my ($self, $c) = @_;
  return;
}

=head2 index_GET_html

=cut

sub index_GET_html : Private {

}

=head2 index_GET

=cut

sub index_GET : Private {
  my ( $self, $c ) = @_;
  $c->stash->{rest} = [];
  return;
}

=head2 index_POST

=cut

sub index_POST :Private {
  my ( $self, $c ) = @_;
  $c->forward('save_upload');
  $c->stash->{rest} = {
    'message' => 'Logo generated successfully',
    'uuid' => $c->stash->{uuid},
    'url' => $c->uri_for('/logo', $c->stash->{uuid})->as_string
  };
}

=head2 index_POST_html

=cut

sub index_POST_html :Private {
  my ( $self, $c ) = @_;
  $c->forward('save_upload');
  $c->res->redirect($c->uri_for('/logo', $c->stash->{uuid}));
}

sub build_logo : Private {
  my ($self, $c) = @_;

  my $hmm_file = $c->stash->{data_dir};
  # convert uploaded file to hmm if not already an hmm
  my $hmm = undef;
  try {
    $hmm = $c->model('Logo::Processing')->convert_upload(
      $hmm_file,
      $c->stash->{alignment_logo}
    );
  }
  catch {
    $c->stash->{error} = {'hmmbuild' => $_ };
    $c->stash->{rest}->{error} = $c->stash->{error};
    $c->detach('end');
  };

  return;

}

sub save_upload : Private {
  my ($self, $c) = @_;
  my $uuid = Data::UUID->new()->create_str();
  # split the  uuid into chuncks
  my @dirs = split /-/, $uuid;
  # mkdir the path
  my $data_dir = $c->config->{logo_dir} .'/'. join '/', @dirs;
  make_path($data_dir);
  # save uploaded file into the new directory
  my $upload = $c->req->upload('file');

  if (!$upload) {
    $c->stash->{error} = {
      'upload' => 'Please choose an alignment or HMM file to upload.'
    };
    $c->stash->{rest}->{error} = $c->stash->{error};
    $c->detach('end');
  }
  else {
    my $new_path = "$data_dir/upload";
    copy($upload->tempname, $new_path);
    # save this info for later use.
    $c->stash->{uuid} = $uuid;
    $c->stash->{data_dir} = $data_dir;

    open my $options, '>', "$data_dir/options";
    my $params = $c->req->params;

    # need to loop over params and validate here, before we store them.
    my @allowed = qw(height_calc logo_type file);
    my $valid = {};

    for my $param (@allowed) {
      if (exists $params->{$param}) {
        $valid->{$param} = $params->{$param};
      }
    }
    # if we got nothing, then we dont want the json encode to blow up.
    $params ||= {};
    my $json = JSON->new->encode($valid);
    print $options $json;
    close $options;

    #check if we want an alignment only logo
    if ($c->req->param('logo_type')) {
      if ($c->req->param('logo_type') eq 'alignment') {
        $c->stash->{alignment_logo} = 1;
      }
      else {
        $c->stash->{alignment_logo} = 0;
      }
    }

    $c->forward('build_logo');
  }
  return;
}


=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('Serialize') {}

sub _deserialize_image {
  return 1;
}

sub _serialize_image {
  my ($data, $self, $c) = @_;
  return $data;
}

=head1 AUTHOR

Clements, Jody

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
