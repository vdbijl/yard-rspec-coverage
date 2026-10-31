// Opens or closes all examples of a method at once.
document.addEventListener('click', function(event) {
  const toggle = event.target.closest('.rspec_toggle');
  if (!toggle) return;

  event.preventDefault();
  const all_details = toggle.closest('.rspec_examples').querySelectorAll('details');
  const open = !Array.from(all_details).every(details => details.open);
  all_details.forEach(details => { details.open = open; });
  toggle.textContent = open ? 'collapse all' : 'expand all';
});
