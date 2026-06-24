import { Config } from '@stencil/core';

// https://stenciljs.com/docs/config

export const config: Config = {
   globalStyle: 'src/global/app.css',
   globalScript: 'src/global/app.ts',
   taskQueue: 'async',
   outputTargets: [
      {
         type: 'www',
         // comment the following line to disable service workers in production
         serviceWorker: null,
         baseUrl: 'https://localhost:7221/host-annotation-app/',
         copy: [
            //{ src: "../node_modules/datatables.net-dt/css/jquery.dataTables.min.css", dest: "assets/css/jquery.dataTables.min.css" },
            { src: "../node_modules/sweetalert2/dist/sweetalert2.min.css", dest: "assets/css/sweetalert2.min.css" }
         ]
      }
   ]
};
