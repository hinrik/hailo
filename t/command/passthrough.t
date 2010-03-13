use 5.010;
use strict;
use warnings;
use Hailo::Command;
use Test::More tests => 15;

my $hc = Hailo::Command->new;

# --autosave
is($hc->save_on_exit, 1, "Default Hailo autosave");
is($hc->_go_autosave, undef, "Default Command autosave");
$hc->_go_autosave(0);
is($hc->save_on_exit, 0, "Hailo autosave matches set command autosave");

# --order
is($hc->order, 2, "Default Hailo order");
is($hc->_go_order, undef, "Default Command order");
$hc->_go_order(50);
is($hc->order, 50, "Hailo order matches set command order");

# --storage-class
is($hc->storage_class, "SQLite", "Default Hailo storage");
is($hc->_go_storage_class, undef, "Default Command storage");
$hc->_go_storage_class("Pg");
is($hc->storage_class, "Pg", "Hailo storage matches set command storage");

# --tokenizer-class
is($hc->tokenizer_class, "Words", "Default Hailo tokenizer");
is($hc->_go_tokenizer_class, undef, "Default Command tokenizer");
$hc->_go_tokenizer_class("Chars");
is($hc->tokenizer_class, "Chars", "Hailo tokenizer matches set command tokenizer");

# --ui-class
is($hc->ui_class, "ReadLine", "Default Hailo ui");
is($hc->_go_ui_class, undef, "Default Command ui");
$hc->_go_ui_class("Wx");
is($hc->ui_class, "Wx", "Hailo ui matches set command ui");

