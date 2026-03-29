(function(){
  let timer = null;

  function byId(id){ return document.getElementById(id); }

  function escapeHtml(v){
    return (v || '').toString().replace(/[&<>"']/g, function(ch){
      return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch];
    });
  }

  function renderFlow(flow){
    const box = byId('flow');
    if(!box){ return; }
    if(!Array.isArray(flow) || !flow.length){ box.innerHTML = '<div>No tracking flow available.</div>'; return; }

    box.innerHTML = flow.map(function(step){
      const cls = step.active ? 'step active' : (step.completed ? 'step done' : 'step');
      return '<div class="' + cls + '">' + escapeHtml(step.name || '-') + '</div>';
    }).join('');
  }

  function renderLocation(loc){
    const mapBox = byId('mapBox');
    const coord = byId('coordInfo');
    if(!mapBox || !coord){ return; }

    if(!loc || typeof loc !== 'object'){
      mapBox.textContent = 'Location not available yet.';
      coord.textContent = '';
      return;
    }

    const lat = Number(loc.latitude);
    const lng = Number(loc.longitude);
    if(!Number.isFinite(lat) || !Number.isFinite(lng)){
      mapBox.textContent = 'Invalid location coordinates.';
      coord.textContent = '';
      return;
    }

    const src = 'https://maps.google.com/maps?q=' + encodeURIComponent(lat + ',' + lng) + '&z=15&output=embed';
    mapBox.innerHTML = '<iframe title="Delivery Location" width="100%" height="100%" style="border:0" loading="lazy" referrerpolicy="no-referrer-when-downgrade" src="' + src + '"></iframe>';
    coord.textContent = 'Latitude: ' + lat.toFixed(6) + ' | Longitude: ' + lng.toFixed(6) + ' | Time: ' + (loc.timestamp || '-');
  }

  async function fetchTracking(orderId){
    const res = await fetch('/track-order?order_id=' + encodeURIComponent(orderId), {
      headers: { 'Accept': 'application/json' }
    });
    return await res.json();
  }

  async function loadTracking(){
    const orderInput = byId('orderIdInput');
    if(!orderInput){ return; }

    const orderId = (orderInput.value || '').trim();
    if(!orderId){
      alert('Enter order ID');
      return;
    }

    const data = await fetchTracking(orderId);
    if(data.error){
      byId('orderMeta').textContent = data.error;
      renderFlow([]);
      renderLocation(null);
      return;
    }

    byId('orderMeta').textContent = 'Order ID: ' + (data.order_id || orderId) + ' | Status: ' + (data.status || '-');
    byId('agentInfo').textContent = 'Delivery Agent: ' + (data.delivery_agent_name || 'Not assigned');
    byId('etaInfo').textContent = 'Estimated Delivery Time: ' + (data.estimated_delivery_time || '-');
    renderFlow(data.flow || []);
    renderLocation(data.latest_location);

    const url = new URL(window.location.href);
    url.searchParams.set('order_id', orderId);
    window.history.replaceState({}, '', url.toString());
  }

  function startAutoRefresh(){
    if(timer){ clearInterval(timer); }
    timer = setInterval(function(){
      const orderInput = byId('orderIdInput');
      if(orderInput && (orderInput.value || '').trim()){
        loadTracking().catch(function(){ /* no-op */ });
      }
    }, 20000);
  }

  window.loadTracking = function(){
    loadTracking().catch(function(err){
      console.error(err);
      alert('Unable to load tracking right now.');
    });
  };

  document.addEventListener('DOMContentLoaded', function(){
    const queryOrderId = new URLSearchParams(window.location.search).get('order_id') || '';
    const input = byId('orderIdInput');
    if(input && queryOrderId && !input.value){
      input.value = queryOrderId;
    }

    if(input && (input.value || '').trim()){
      loadTracking().catch(function(){ /* no-op */ });
    }
    startAutoRefresh();
  });
})();
