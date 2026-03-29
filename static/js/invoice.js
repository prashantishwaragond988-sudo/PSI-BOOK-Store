(function(){
  function init(){
    const printBtn = document.getElementById('printBtn');
    if(printBtn){
      printBtn.addEventListener('click', function(){
        window.print();
      });
    }
  }

  if(document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', init);
  }else{
    init();
  }
})();
